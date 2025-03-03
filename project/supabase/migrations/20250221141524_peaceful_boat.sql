/*
  # Simplified Orders Schema

  1. New Tables
    - orders: Core order information
    - order_items: Line items for each order
    - order_assignments: Worker assignments for orders

  2. Changes
    - Creates new simplified schema
    - Adds proper indexes and constraints
    - Sets up RLS policies
    - Configures order number generation

  3. Security
    - Enables RLS on all tables
    - Creates permissive policies for testing
*/

-- Create orders table first
CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations ON DELETE CASCADE NOT NULL,
  client_id uuid REFERENCES clients ON DELETE CASCADE NOT NULL,
  order_number text UNIQUE,
  description text,
  total_amount numeric(10,2) NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')) DEFAULT 'pending',
  due_date date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create order items table
CREATE TABLE order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  price numeric(10,2) NOT NULL DEFAULT 0,
  total numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create worker assignments table
CREATE TABLE order_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders ON DELETE CASCADE NOT NULL,
  worker_id uuid REFERENCES workers ON DELETE CASCADE NOT NULL,
  status text NOT NULL CHECK (status IN ('pending', 'in_progress', 'completed')) DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(order_id, worker_id)
);

-- Create indexes
CREATE INDEX idx_orders_organization ON orders(organization_id);
CREATE INDEX idx_orders_client ON orders(client_id);
CREATE INDEX idx_orders_number ON orders(order_number);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_assignments_order ON order_assignments(order_id);
CREATE INDEX idx_order_assignments_worker ON order_assignments(worker_id);

-- Create order number generation function
CREATE OR REPLACE FUNCTION generate_order_number()
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
  SELECT string_agg(left(word, 1), '')
  INTO org_prefix
  FROM (
    SELECT regexp_split_to_table(upper(name), '\s+') as word
    FROM organizations
    WHERE id = NEW.organization_id
  ) words;

  -- Get current year and month
  current_ym := to_char(NEW.created_at, 'YYYYMM');
  
  -- Create sequence name
  sequence_name := 'order_seq_' || NEW.organization_id || '_' || current_ym;
  
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
CREATE TRIGGER set_order_number
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION generate_order_number();

-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_assignments ENABLE ROW LEVEL SECURITY;

-- Create temporary permissive policies for testing
CREATE POLICY "temp_allow_all_orders"
  ON orders FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "temp_allow_all_items"
  ON order_items FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "temp_allow_all_assignments"
  ON order_assignments FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Grant permissions
GRANT ALL ON orders TO authenticated;
GRANT ALL ON order_items TO authenticated;
GRANT ALL ON order_assignments TO authenticated;

-- Grant sequence permissions
DO $$
DECLARE
    seq_name text;
BEGIN
    FOR seq_name IN 
        SELECT sequence_name 
        FROM information_schema.sequences 
        WHERE sequence_schema = 'public'
    LOOP
        EXECUTE format('GRANT ALL ON SEQUENCE %I TO authenticated', seq_name);
    END LOOP;
END
$$;