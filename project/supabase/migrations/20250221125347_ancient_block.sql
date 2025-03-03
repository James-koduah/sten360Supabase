/*
  # Fix order permissions

  1. Changes
    - Drop existing policies
    - Create new simplified policies for orders and related tables
    - Grant proper permissions to authenticated users
*/

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "organizations_owner_manage_orders" ON orders;
DROP POLICY IF EXISTS "organizations_owner_manage_order_services" ON order_services;
DROP POLICY IF EXISTS "organizations_owner_manage_order_custom_fields" ON order_custom_fields;

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

-- Grant proper permissions
GRANT ALL ON orders TO authenticated;
GRANT ALL ON order_services TO authenticated;
GRANT ALL ON order_custom_fields TO authenticated;
GRANT ALL ON order_workers TO authenticated;
GRANT ALL ON SEQUENCE order_number_seq TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;