-- Drop all existing policies for order_workers
DROP POLICY IF EXISTS "organizations_owner_select_order_workers" ON order_workers;
DROP POLICY IF EXISTS "organizations_owner_insert_order_workers" ON order_workers;
DROP POLICY IF EXISTS "organizations_owner_update_order_workers" ON order_workers;
DROP POLICY IF EXISTS "organizations_owner_delete_order_workers" ON order_workers;
DROP POLICY IF EXISTS "organizations_owner_manage_order_workers" ON order_workers;

-- Create a single unified policy for all operations
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