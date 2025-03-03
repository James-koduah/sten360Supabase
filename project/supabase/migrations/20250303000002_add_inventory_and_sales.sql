-- Drop existing tables first (in correct order to handle dependencies)
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS sales_order_items;
DROP TABLE IF EXISTS sales_orders;
DROP TABLE IF EXISTS products;
DROP TYPE IF EXISTS payment_status;
DROP TYPE IF EXISTS payment_method;
DROP TYPE IF EXISTS product_category;

-- Create enums
CREATE TYPE product_category AS ENUM ('raw_material', 'finished_good', 'packaging', 'other');
CREATE TYPE payment_method AS ENUM ('cash', 'mobile_money', 'bank_transfer', 'other');
CREATE TYPE payment_status AS ENUM ('unpaid', 'partially_paid', 'paid');

-- Create all tables first
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  category product_category NOT NULL,
  sku TEXT NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL DEFAULT 0,
  stock_quantity INTEGER NOT NULL DEFAULT 0,
  reorder_point INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT positive_price CHECK (unit_price >= 0),
  CONSTRAINT positive_quantity CHECK (stock_quantity >= 0),
  CONSTRAINT positive_reorder CHECK (reorder_point >= 0),
  CONSTRAINT unique_sku UNIQUE (organization_id, sku)
);

CREATE TABLE sales_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  order_number TEXT NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  outstanding_balance DECIMAL(10,2) NOT NULL DEFAULT 0,
  payment_status payment_status NOT NULL DEFAULT 'unpaid',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT positive_total CHECK (total_amount >= 0),
  CONSTRAINT positive_balance CHECK (outstanding_balance >= 0),
  CONSTRAINT unique_order_number UNIQUE (organization_id, order_number)
);

CREATE TABLE sales_order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sales_order_id UUID NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  total_price DECIMAL(10,2) NOT NULL,
  is_custom_item BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT positive_quantity CHECK (quantity > 0),
  CONSTRAINT positive_unit_price CHECK (unit_price >= 0),
  CONSTRAINT positive_total_price CHECK (total_price >= 0)
);

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sales_order_id UUID NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
  payment_method payment_method NOT NULL,
  transaction_reference TEXT,
  recorded_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT positive_payment CHECK (amount > 0)
);

-- Create indexes for better performance
CREATE INDEX idx_products_organization ON products(organization_id);
CREATE INDEX idx_sales_orders_organization ON sales_orders(organization_id);
CREATE INDEX idx_sales_orders_client ON sales_orders(client_id);
CREATE INDEX idx_sales_order_items_order ON sales_order_items(sales_order_id);
CREATE INDEX idx_payments_order ON payments(sales_order_id);

-- Enable RLS
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their organization's products"
  ON products FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users_organizations uo
    WHERE uo.organization_id = products.organization_id
    AND uo.user_id = auth.uid()
  ));

CREATE POLICY "Users can insert their organization's products"
  ON products FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM users_organizations uo
    WHERE uo.organization_id = organization_id
    AND uo.user_id = auth.uid()
  ));

CREATE POLICY "Users can update their organization's products"
  ON products FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users_organizations uo
    WHERE uo.organization_id = products.organization_id
    AND uo.user_id = auth.uid()
  ));

CREATE POLICY "Users can delete their organization's products"
  ON products FOR DELETE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users_organizations uo
    WHERE uo.organization_id = products.organization_id
    AND uo.user_id = auth.uid()
  ));

-- Sales orders policies
CREATE POLICY "Users can view their organization's sales orders"
  ON sales_orders FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users_organizations uo
    WHERE uo.organization_id = sales_orders.organization_id
    AND uo.user_id = auth.uid()
  ));

CREATE POLICY "Users can insert their organization's sales orders"
  ON sales_orders FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM users_organizations uo
    WHERE uo.organization_id = organization_id
    AND uo.user_id = auth.uid()
  ));

CREATE POLICY "Users can update their organization's sales orders"
  ON sales_orders FOR UPDATE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users_organizations uo
    WHERE uo.organization_id = sales_orders.organization_id
    AND uo.user_id = auth.uid()
  ));

CREATE POLICY "Users can delete their organization's sales orders"
  ON sales_orders FOR DELETE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM users_organizations uo
    WHERE uo.organization_id = sales_orders.organization_id
    AND uo.user_id = auth.uid()
  ));

-- Sales order items policies
CREATE POLICY "Users can view their organization's sales order items"
  ON sales_order_items FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert their organization's sales order items"
  ON sales_order_items FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update their organization's sales order items"
  ON sales_order_items FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Users can delete their organization's sales order items"
  ON sales_order_items FOR DELETE
  TO authenticated
  USING (true);

-- Payments policies
CREATE POLICY "Users can view their organization's payments"
  ON payments FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert their organization's payments"
  ON payments FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update their organization's payments"
  ON payments FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Users can delete their organization's payments"
  ON payments FOR DELETE
  TO authenticated
  USING (true);

-- Function to generate order number
CREATE OR REPLACE FUNCTION generate_sales_order_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  org_prefix text;
  current_ym text;
  next_number int;
  sequence_name text;
BEGIN
  -- Get organization name prefix
  SELECT COALESCE(
    (SELECT string_agg(left(word, 1), '')
    FROM (
      SELECT regexp_split_to_table(upper(name), '\s+') as word
      FROM organizations
      WHERE id = NEW.organization_id
    ) words),
    'SO'
  ) INTO org_prefix;

  -- Get current year and month
  current_ym := to_char(NEW.created_at, 'YYYYMM');
  
  -- Create sequence name
  sequence_name := 'sales_order_seq_' || NEW.organization_id || '_' || current_ym;
  
  -- Create sequence if needed
  EXECUTE format('
    CREATE SEQUENCE IF NOT EXISTS %I START WITH 1001', sequence_name
  );
  
  -- Get next number
  EXECUTE format('SELECT nextval(%L)', sequence_name) INTO next_number;

  -- Set order number
  NEW.order_number := org_prefix || '-' || current_ym || '-' || lpad(next_number::text, 4, '0');
  
  RETURN NEW;
END;
$$;

-- Create trigger for order number generation
DROP TRIGGER IF EXISTS set_sales_order_number ON sales_orders;
CREATE TRIGGER set_sales_order_number
  BEFORE INSERT ON sales_orders
  FOR EACH ROW
  EXECUTE FUNCTION generate_sales_order_number(); 