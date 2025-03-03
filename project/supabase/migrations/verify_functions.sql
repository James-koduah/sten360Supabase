-- Drop all triggers first
DROP TRIGGER IF EXISTS create_tasks_on_order_worker ON order_workers;
DROP TRIGGER IF EXISTS set_order_number ON orders;
DROP TRIGGER IF EXISTS update_payment_status_on_payment ON payments;

-- Drop existing functions to recreate them
DROP FUNCTION IF EXISTS create_order(uuid, uuid, text, date, numeric, jsonb[], jsonb[], uuid[]);
DROP FUNCTION IF EXISTS record_payment(uuid, uuid, numeric, text, text, uuid);
DROP FUNCTION IF EXISTS create_tasks_for_order_workers();
DROP FUNCTION IF EXISTS generate_order_number();
DROP FUNCTION IF EXISTS update_order_payment_status();

-- Add required columns to orders table
DO $$ 
BEGIN
    -- Add payment_status if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'payment_status') THEN
        ALTER TABLE orders ADD COLUMN payment_status text DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'partially_paid', 'paid'));
    END IF;
    
    -- Add outstanding_balance if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'outstanding_balance') THEN
        ALTER TABLE orders ADD COLUMN outstanding_balance numeric DEFAULT 0;
    END IF;
END $$;

-- Add required columns to payments table
DO $$ 
BEGIN
    -- Create payments table if it doesn't exist
    CREATE TABLE IF NOT EXISTS payments (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        organization_id uuid REFERENCES organizations(id) ON DELETE CASCADE,
        order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
        amount numeric NOT NULL,
        payment_method text NOT NULL,
        payment_reference text,
        recorded_by uuid REFERENCES auth.users(id),
        created_at timestamptz DEFAULT now(),
        updated_at timestamptz DEFAULT now()
    );
    
    -- Add columns if they don't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payments' AND column_name = 'created_at') THEN
        ALTER TABLE payments ADD COLUMN created_at timestamptz DEFAULT now();
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'payments' AND column_name = 'updated_at') THEN
        ALTER TABLE payments ADD COLUMN updated_at timestamptz DEFAULT now();
    END IF;
END $$;

-- Add order_id column to tasks table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'tasks' 
        AND column_name = 'order_id'
    ) THEN
        ALTER TABLE tasks ADD COLUMN order_id uuid REFERENCES orders(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Create order number generation function
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.order_number := 'ORD-' || to_char(NOW(), 'YYYYMMDD') || '-' || 
                       LPAD(COALESCE(
                           (SELECT COUNT(*) + 1 
                            FROM orders 
                            WHERE DATE_TRUNC('day', created_at) = DATE_TRUNC('day', NOW())
                           )::text,
                           '1'
                       ), 4, '0');
    RETURN NEW;
END;
$$;

-- Create task creation function
CREATE OR REPLACE FUNCTION create_tasks_for_order_workers()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO tasks (
        organization_id,
        worker_id,
        project_id,
        order_id,
        status,
        created_at,
        updated_at
    )
    SELECT
        o.organization_id,
        NEW.worker_id,
        NEW.project_id,
        NEW.order_id,
        'pending',
        NOW(),
        NOW()
    FROM orders o
    WHERE o.id = NEW.order_id;
    
    RETURN NEW;
END;
$$;

-- Create payment status update function before other functions
CREATE OR REPLACE FUNCTION update_order_payment_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE orders o
    SET payment_status = 
        CASE 
            WHEN o.total_amount <= COALESCE((
                SELECT SUM(amount)
                FROM payments p
                WHERE p.order_id = o.id
            ), 0) THEN 'paid'
            WHEN COALESCE((
                SELECT SUM(amount)
                FROM payments p
                WHERE p.order_id = o.id
            ), 0) > 0 THEN 'partially_paid'
            ELSE 'unpaid'
        END,
        outstanding_balance = o.total_amount - COALESCE((
            SELECT SUM(amount)
            FROM payments p
            WHERE p.order_id = o.id
        ), 0)
    WHERE o.id = NEW.order_id;
    
    RETURN NEW;
END;
$$;

-- Create record payment function
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
    -- Insert the payment record
    INSERT INTO payments (
        organization_id,
        order_id,
        amount,
        payment_method,
        payment_reference,
        recorded_by,
        created_at,
        updated_at
    )
    VALUES (
        p_organization_id,
        p_order_id,
        p_amount,
        p_payment_method,
        p_payment_reference,
        p_recorded_by,
        NOW(),
        NOW()
    )
    RETURNING id INTO v_payment_id;

    -- Get the created payment with details
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

-- Recreate the functions
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
  -- Create order
  INSERT INTO orders (
    organization_id,
    client_id,
    description,
    due_date,
    total_amount,
    status,
    payment_status,
    outstanding_balance
  )
  VALUES (
    p_organization_id,
    p_client_id,
    p_description,
    p_due_date,
    p_total_amount,
    'pending',
    'unpaid',
    p_total_amount
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
END;
$$;

-- Add INSERT policies for all tables
DROP POLICY IF EXISTS orders_insert ON orders;
CREATE POLICY orders_insert ON orders FOR INSERT TO authenticated
  WITH CHECK (organization_id IN (
    SELECT id FROM organizations WHERE owner_id = auth.uid()
  ));

DROP POLICY IF EXISTS order_services_insert ON order_services;
CREATE POLICY order_services_insert ON order_services FOR INSERT TO authenticated
  WITH CHECK (order_id IN (
    SELECT o.id FROM orders o
    JOIN organizations org ON org.id = o.organization_id
    WHERE org.owner_id = auth.uid()
  ));

DROP POLICY IF EXISTS order_workers_insert ON order_workers;
CREATE POLICY order_workers_insert ON order_workers FOR INSERT TO authenticated
  WITH CHECK (order_id IN (
    SELECT o.id FROM orders o
    JOIN organizations org ON org.id = o.organization_id
    WHERE org.owner_id = auth.uid()
  ));

DROP POLICY IF EXISTS order_custom_fields_insert ON order_custom_fields;
CREATE POLICY order_custom_fields_insert ON order_custom_fields FOR INSERT TO authenticated
  WITH CHECK (order_id IN (
    SELECT o.id FROM orders o
    JOIN organizations org ON org.id = o.organization_id
    WHERE org.owner_id = auth.uid()
  ));

DROP POLICY IF EXISTS payments_insert ON payments;
CREATE POLICY payments_insert ON payments FOR INSERT TO authenticated
  WITH CHECK (order_id IN (
    SELECT o.id FROM orders o
    JOIN organizations org ON org.id = o.organization_id
    WHERE org.owner_id = auth.uid()
  ));

-- Grant necessary permissions
GRANT ALL ON orders TO authenticated;
GRANT ALL ON order_services TO authenticated;
GRANT ALL ON order_workers TO authenticated;
GRANT ALL ON order_custom_fields TO authenticated;
GRANT ALL ON payments TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant function execution permissions
GRANT EXECUTE ON FUNCTION create_order(uuid, uuid, text, date, numeric, jsonb[], jsonb[], uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION record_payment(uuid, uuid, numeric, text, text, uuid) TO authenticated;

-- Verify RLS is enabled
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_custom_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Recreate all triggers
CREATE TRIGGER create_tasks_on_order_worker
    AFTER INSERT ON order_workers
    FOR EACH ROW
    EXECUTE FUNCTION create_tasks_for_order_workers();

CREATE TRIGGER set_order_number
    BEFORE INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION generate_order_number();

CREATE TRIGGER update_payment_status_on_payment
    AFTER INSERT OR UPDATE OR DELETE ON payments
    FOR EACH ROW
    EXECUTE FUNCTION update_order_payment_status();

-- Add useful indexes
CREATE INDEX IF NOT EXISTS idx_orders_organization_id ON orders(organization_id);
CREATE INDEX IF NOT EXISTS idx_orders_client_id ON orders(client_id);
CREATE INDEX IF NOT EXISTS idx_order_workers_order_id ON order_workers(order_id);
CREATE INDEX IF NOT EXISTS idx_order_services_order_id ON order_services(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_tasks_order_id ON tasks(order_id); 