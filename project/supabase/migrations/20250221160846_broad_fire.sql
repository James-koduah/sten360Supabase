-- Create tables if they don't exist
DO $$ 
BEGIN
  -- Create orders table if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'orders') THEN
    CREATE TABLE orders (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      organization_id uuid REFERENCES organizations ON DELETE CASCADE NOT NULL,
      client_id uuid REFERENCES clients ON DELETE CASCADE NOT NULL,
      order_number text UNIQUE,
      description text,
      due_date date,
      status text NOT NULL CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')) DEFAULT 'pending',
      total_amount numeric(10,2) NOT NULL DEFAULT 0,
      initial_payment numeric(10,2) DEFAULT 0,
      outstanding_balance numeric(10,2) GENERATED ALWAYS AS (total_amount - initial_payment) STORED,
      payment_status text NOT NULL CHECK (payment_status IN ('pending', 'partially_paid', 'fully_paid')) DEFAULT 'pending',
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now()
    );
  END IF;

  -- Create payments table if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payments') THEN
    CREATE TABLE payments (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      organization_id uuid REFERENCES organizations ON DELETE CASCADE NOT NULL,
      order_id uuid REFERENCES orders ON DELETE CASCADE NOT NULL,
      amount numeric(10,2) NOT NULL CHECK (amount > 0),
      payment_method text NOT NULL CHECK (payment_method IN ('mobile_money', 'bank_transfer', 'cash', 'other')),
      payment_reference text,
      recorded_by uuid REFERENCES auth.users ON DELETE SET NULL,
      created_at timestamptz DEFAULT now()
    );
  END IF;

  -- Create payment_method_details table if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payment_method_details') THEN
    CREATE TABLE payment_method_details (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      organization_id uuid REFERENCES organizations ON DELETE CASCADE NOT NULL,
      payment_method text NOT NULL CHECK (payment_method IN ('mobile_money', 'bank_transfer', 'cash', 'other')),
      details jsonb NOT NULL DEFAULT '{}'::jsonb,
      is_active boolean DEFAULT true,
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now(),
      UNIQUE(organization_id, payment_method)
    );
  END IF;

  -- Create order_services table if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_services') THEN
    CREATE TABLE order_services (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      order_id uuid REFERENCES orders ON DELETE CASCADE NOT NULL,
      service_id uuid REFERENCES services ON DELETE CASCADE NOT NULL,
      quantity integer NOT NULL DEFAULT 1,
      cost numeric(10,2) NOT NULL DEFAULT 0,
      created_at timestamptz DEFAULT now()
    );
  END IF;

  -- Create order_workers table if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_workers') THEN
    CREATE TABLE order_workers (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      order_id uuid REFERENCES orders ON DELETE CASCADE NOT NULL,
      worker_id uuid REFERENCES workers ON DELETE CASCADE NOT NULL,
      project_id uuid REFERENCES projects ON DELETE CASCADE NOT NULL,
      status text NOT NULL CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')) DEFAULT 'pending',
      created_at timestamptz DEFAULT now()
    );
  END IF;

  -- Create order_custom_fields table if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_custom_fields') THEN
    CREATE TABLE order_custom_fields (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      order_id uuid REFERENCES orders ON DELETE CASCADE NOT NULL,
      field_id uuid REFERENCES client_custom_fields ON DELETE CASCADE NOT NULL,
      created_at timestamptz DEFAULT now(),
      UNIQUE(order_id, field_id)
    );
  END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_orders_organization ON orders(organization_id);
CREATE INDEX IF NOT EXISTS idx_orders_client ON orders(client_id);
CREATE INDEX IF NOT EXISTS idx_orders_number ON orders(order_number);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_services_order ON order_services(order_id);
CREATE INDEX IF NOT EXISTS idx_order_services_service ON order_services(service_id);
CREATE INDEX IF NOT EXISTS idx_order_workers_order ON order_workers(order_id);
CREATE INDEX IF NOT EXISTS idx_order_workers_worker ON order_workers(worker_id);
CREATE INDEX IF NOT EXISTS idx_order_workers_project ON order_workers(project_id);
CREATE INDEX IF NOT EXISTS idx_order_workers_status ON order_workers(status);
CREATE INDEX IF NOT EXISTS idx_order_custom_fields_order ON order_custom_fields(order_id);
CREATE INDEX IF NOT EXISTS idx_order_custom_fields_field ON order_custom_fields(field_id);

-- Create indexes for new tables
CREATE INDEX IF NOT EXISTS idx_payments_organization ON payments(organization_id);
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_recorded_by ON payments(recorded_by);
CREATE INDEX IF NOT EXISTS idx_payment_method_details_organization ON payment_method_details(organization_id);

-- Drop existing functions and triggers
DROP TRIGGER IF EXISTS set_order_number ON orders;
DROP FUNCTION IF EXISTS generate_order_number();
DROP TRIGGER IF EXISTS create_tasks_on_order_worker ON order_workers;
DROP FUNCTION IF EXISTS create_tasks_for_order_workers();
DROP FUNCTION IF EXISTS create_order(uuid, uuid, text, date, numeric, jsonb[], jsonb[], uuid[]);

-- Create order number generation function
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

-- Create function to create tasks for assigned workers
CREATE OR REPLACE FUNCTION create_tasks_for_order_workers()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_organization_id uuid;
BEGIN
  -- Get organization ID
  SELECT o.organization_id INTO v_organization_id
  FROM orders o
  WHERE o.id = NEW.order_id;

  IF v_organization_id IS NULL THEN
    RAISE EXCEPTION 'Order not found or missing organization_id';
  END IF;

  -- Create task for the worker
  INSERT INTO tasks (
    organization_id,
    worker_id,
    project_id,
    description,
    date,
    status,
    status_changed_at,
    amount
  )
  SELECT
    v_organization_id,
    NEW.worker_id,
    NEW.project_id,
    CASE 
      WHEN o.description IS NOT NULL AND o.description != '' 
      THEN 'Order ' || o.order_number || ': ' || o.description
      ELSE 'Order ' || o.order_number
    END,
    COALESCE(o.due_date, CURRENT_DATE),
    'pending',
    now(),
    wp.rate
  FROM orders o
  JOIN worker_project_rates wp ON wp.worker_id = NEW.worker_id AND wp.project_id = NEW.project_id
  WHERE o.id = NEW.order_id;

  RETURN NEW;
END;
$$;

-- Create trigger for task creation
CREATE TRIGGER create_tasks_on_order_worker
  AFTER INSERT ON order_workers
  FOR EACH ROW
  EXECUTE FUNCTION create_tasks_for_order_workers();

-- Create stored procedure for order creation
CREATE OR REPLACE FUNCTION create_order(
  p_organization_id uuid,
  p_client_id uuid,
  p_description text,
  p_due_date date,
  p_total_amount numeric,
  p_workers jsonb[],
  p_services jsonb[],
  p_custom_fields uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id uuid;
  v_order jsonb;
BEGIN
  -- Start transaction
  BEGIN
    -- Create order
    INSERT INTO orders (
      organization_id,
      client_id,
      description,
      due_date,
      total_amount,
      status
    )
    VALUES (
      p_organization_id,
      p_client_id,
      p_description,
      p_due_date,
      p_total_amount,
      'pending'
    )
    RETURNING id INTO v_order_id;

    -- Add workers
    INSERT INTO order_workers (
      order_id,
      worker_id,
      project_id,
      status
    )
    SELECT
      v_order_id,
      (worker->>'worker_id')::uuid,
      (worker->>'project_id')::uuid,
      'pending'
    FROM unnest(p_workers) AS worker;

    -- Add services
    INSERT INTO order_services (
      order_id,
      service_id,
      quantity,
      cost
    )
    SELECT
      v_order_id,
      (service->>'service_id')::uuid,
      (service->>'quantity')::integer,
      (service->>'cost')::numeric
    FROM unnest(p_services) AS service;

    -- Add custom fields if any
    IF p_custom_fields IS NOT NULL AND array_length(p_custom_fields, 1) > 0 THEN
      INSERT INTO order_custom_fields (
        order_id,
        field_id
      )
      SELECT
        v_order_id,
        field_id
      FROM unnest(p_custom_fields) AS field_id;
    END IF;

    -- Get the created order with all its details
    SELECT jsonb_build_object(
      'id', o.id,
      'order_number', o.order_number,
      'client_id', o.client_id,
      'description', o.description,
      'due_date', o.due_date,
      'status', o.status,
      'total_amount', o.total_amount,
      'created_at', o.created_at,
      'workers', COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', ow.id,
          'worker_id', ow.worker_id,
          'project_id', ow.project_id,
          'status', ow.status
        )
      ) FILTER (WHERE ow.id IS NOT NULL), '[]'::jsonb)
    ) INTO v_order
    FROM orders o
    LEFT JOIN order_workers ow ON ow.order_id = o.id
    WHERE o.id = v_order_id
    GROUP BY o.id;

    RETURN v_order;
  EXCEPTION
    WHEN OTHERS THEN
      -- Rollback will happen automatically
      RAISE EXCEPTION 'Failed to create order: %', SQLERRM;
  END;
END;
$$;

-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_custom_fields ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies first
DROP POLICY IF EXISTS "temp_allow_all_orders" ON orders;
DROP POLICY IF EXISTS "temp_allow_all_order_services" ON order_services;
DROP POLICY IF EXISTS "temp_allow_all_order_workers" ON order_workers;
DROP POLICY IF EXISTS "temp_allow_all_order_custom_fields" ON order_custom_fields;
DROP POLICY IF EXISTS "owner_manage_orders" ON orders;
DROP POLICY IF EXISTS "owner_manage_order_services" ON order_services;
DROP POLICY IF EXISTS "owner_manage_order_workers" ON order_workers;
DROP POLICY IF EXISTS "owner_manage_order_custom_fields" ON order_custom_fields;

-- Create new policies
CREATE POLICY "temp_allow_all_orders"
  ON orders FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "temp_allow_all_order_services"
  ON order_services FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "temp_allow_all_order_workers"
  ON order_workers FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "temp_allow_all_order_custom_fields"
  ON order_custom_fields FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Grant all necessary permissions
GRANT ALL ON orders TO authenticated;
GRANT ALL ON order_services TO authenticated;
GRANT ALL ON order_workers TO authenticated;
GRANT ALL ON order_custom_fields TO authenticated;
GRANT ALL ON tasks TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION create_order(uuid, uuid, text, date, numeric, jsonb[], jsonb[], uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION create_tasks_for_order_workers() TO authenticated;
GRANT EXECUTE ON FUNCTION generate_order_number() TO authenticated;

-- Create function to update order payment status
CREATE OR REPLACE FUNCTION update_order_payment_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_paid numeric(10,2);
  v_total_amount numeric(10,2);
BEGIN
  -- Calculate total paid amount for the order
  SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
  FROM payments
  WHERE order_id = NEW.order_id;

  -- Get order total amount
  SELECT total_amount INTO v_total_amount
  FROM orders
  WHERE id = NEW.order_id;

  -- Update order payment status
  UPDATE orders
  SET 
    payment_status = CASE 
      WHEN v_total_paid >= v_total_amount THEN 'fully_paid'
      WHEN v_total_paid > 0 THEN 'partially_paid'
      ELSE 'pending'
    END,
    updated_at = now()
  WHERE id = NEW.order_id;

  RETURN NEW;
END;
$$;

-- Create trigger for payment status updates
CREATE TRIGGER update_payment_status_on_payment
  AFTER INSERT OR UPDATE OR DELETE ON payments
  FOR EACH ROW
  EXECUTE FUNCTION update_order_payment_status();

-- Create function to record payment
CREATE OR REPLACE FUNCTION record_payment(
  p_organization_id uuid,
  p_order_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_payment_reference text,
  p_recorded_by uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment_id uuid;
  v_payment jsonb;
BEGIN
  -- Validate payment method
  IF p_payment_method NOT IN ('mobile_money', 'bank_transfer', 'cash', 'other') THEN
    RAISE EXCEPTION 'Invalid payment method';
  END IF;

  -- Insert payment record
  INSERT INTO payments (
    organization_id,
    order_id,
    amount,
    payment_method,
    payment_reference,
    recorded_by
  )
  VALUES (
    p_organization_id,
    p_order_id,
    p_amount,
    p_payment_method,
    p_payment_reference,
    p_recorded_by
  )
  RETURNING id INTO v_payment_id;

  -- Get payment details
  SELECT jsonb_build_object(
    'id', p.id,
    'order_id', p.order_id,
    'amount', p.amount,
    'payment_method', p.payment_method,
    'payment_reference', p.payment_reference,
    'recorded_by', p.recorded_by,
    'created_at', p.created_at
  ) INTO v_payment
  FROM payments p
  WHERE p.id = v_payment_id;

  RETURN v_payment;
END;
$$;

-- Enable RLS for new tables
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_method_details ENABLE ROW LEVEL SECURITY;

-- Create policies for new tables
CREATE POLICY "temp_allow_all_payments"
  ON payments FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "temp_allow_all_payment_method_details"
  ON payment_method_details FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Grant permissions for new tables and functions
GRANT ALL ON payments TO authenticated;
GRANT ALL ON payment_method_details TO authenticated;
GRANT EXECUTE ON FUNCTION record_payment(uuid, uuid, numeric, text, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION update_order_payment_status() TO authenticated;