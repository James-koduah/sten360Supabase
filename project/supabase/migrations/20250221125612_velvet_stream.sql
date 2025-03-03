/*
  # Fix database permissions

  1. Changes
    - Grant proper permissions to authenticated users
    - Ensure access to all necessary tables and sequences
    - Fix RLS policies for better security
*/

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO authenticated;

-- Grant table permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Ensure RLS is enabled on all relevant tables
ALTER TABLE IF EXISTS orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS order_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS order_custom_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS order_workers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "organizations_owner_manage_orders" ON orders;
DROP POLICY IF EXISTS "organizations_owner_manage_order_services" ON order_services;
DROP POLICY IF EXISTS "organizations_owner_manage_order_custom_fields" ON order_custom_fields;
DROP POLICY IF EXISTS "organizations_owner_manage_order_workers" ON order_workers;

-- Create simplified policies for orders
CREATE POLICY "organizations_owner_manage_orders"
  ON orders
  TO authenticated
  USING (
    organization_id IN (
      SELECT id FROM organizations WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    organization_id IN (
      SELECT id FROM organizations WHERE owner_id = auth.uid()
    )
  );

-- Create simplified policies for order_services
CREATE POLICY "organizations_owner_manage_order_services"
  ON order_services
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_services.order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  );

-- Create simplified policies for order_custom_fields
CREATE POLICY "organizations_owner_manage_order_custom_fields"
  ON order_custom_fields
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_custom_fields.order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  );

-- Create simplified policies for order_workers
CREATE POLICY "organizations_owner_manage_order_workers"
  ON order_workers
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_workers.order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  );

-- Grant sequence permissions explicitly
DO $$
DECLARE
    seq_name text;
BEGIN
    FOR seq_name IN 
        SELECT sequence_name 
        FROM information_schema.sequences 
        WHERE sequence_schema = 'public'
    LOOP
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %I TO authenticated', seq_name);
    END LOOP;
END
$$;