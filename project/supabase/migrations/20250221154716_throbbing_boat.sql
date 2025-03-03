/*
  # Orders Management System

  1. New Tables
    - orders
      - id (uuid, primary key)
      - organization_id (uuid, references organizations)
      - client_id (uuid, references clients)
      - order_number (text, unique)
      - description (text)
      - due_date (date)
      - status (text)
      - total_amount (numeric)
      - created_at (timestamptz)
      - updated_at (timestamptz)
    
    - order_services
      - id (uuid, primary key)
      - order_id (uuid, references orders)
      - service_id (uuid, references services)
      - quantity (integer)
      - cost (numeric)
      - created_at (timestamptz)
    
    - order_workers
      - id (uuid, primary key)
      - order_id (uuid, references orders)
      - worker_id (uuid, references workers)
      - project_id (uuid, references projects)
      - status (text)
      - created_at (timestamptz)
    
    - order_custom_fields
      - id (uuid, primary key)
      - order_id (uuid, references orders)
      - field_id (uuid, references client_custom_fields)
      - created_at (timestamptz)

  2. Features
    - Automatic order number generation
    - Automatic task creation for assigned workers
    - Cascading deletes for cleanup
    
  3. Security
    - RLS policies for all tables
    - Organization-based access control
*/

-- Create orders table
CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations ON DELETE CASCADE NOT NULL,
  client_id uuid REFERENCES clients ON DELETE CASCADE NOT NULL,
  order_number text UNIQUE,
  description text,
  due_date date,
  status text NOT NULL CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')) DEFAULT 'pending',
  total_amount numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create order_services table
CREATE TABLE order_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders ON DELETE CASCADE NOT NULL,
  service_id uuid REFERENCES services ON DELETE CASCADE NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  cost numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create order_workers table
CREATE TABLE order_workers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders ON DELETE CASCADE NOT NULL,
  worker_id uuid REFERENCES workers ON DELETE CASCADE NOT NULL,
  project_id uuid REFERENCES projects ON DELETE CASCADE NOT NULL,
  status text NOT NULL CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')) DEFAULT 'pending',
  created_at timestamptz DEFAULT now()
);

-- Create order_custom_fields table
CREATE TABLE order_custom_fields (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders ON DELETE CASCADE NOT NULL,
  field_id uuid REFERENCES client_custom_fields ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(order_id, field_id)
);

-- Create indexes
CREATE INDEX idx_orders_organization ON orders(organization_id);
CREATE INDEX idx_orders_client ON orders(client_id);
CREATE INDEX idx_orders_number ON orders(order_number);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_services_order ON order_services(order_id);
CREATE INDEX idx_order_services_service ON order_services(service_id);
CREATE INDEX idx_order_workers_order ON order_workers(order_id);
CREATE INDEX idx_order_workers_worker ON order_workers(worker_id);
CREATE INDEX idx_order_workers_project ON order_workers(project_id);
CREATE INDEX idx_order_workers_status ON order_workers(status);
CREATE INDEX idx_order_custom_fields_order ON order_custom_fields(order_id);
CREATE INDEX idx_order_custom_fields_field ON order_custom_fields(field_id);

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

-- Enable RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_custom_fields ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "owner_manage_orders"
  ON orders
  FOR ALL
  TO authenticated
  USING (organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid()))
  WITH CHECK (organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid()));

CREATE POLICY "owner_manage_order_services"
  ON order_services
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = order_services.order_id
    AND o.organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid())
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = order_id
    AND o.organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid())
  ));

CREATE POLICY "owner_manage_order_workers"
  ON order_workers
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = order_workers.order_id
    AND o.organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid())
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = order_id
    AND o.organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid())
  ));

CREATE POLICY "owner_manage_order_custom_fields"
  ON order_custom_fields
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = order_custom_fields.order_id
    AND o.organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid())
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = order_id
    AND o.organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid())
  ));

-- Grant permissions
GRANT ALL ON orders TO authenticated;
GRANT ALL ON order_services TO authenticated;
GRANT ALL ON order_workers TO authenticated;
GRANT ALL ON order_custom_fields TO authenticated;