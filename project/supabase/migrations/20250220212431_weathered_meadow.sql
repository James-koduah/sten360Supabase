/*
  # Add Order Workers Support

  1. New Tables
    - `order_workers`: Links orders to workers and their assigned projects
      - `id` (uuid, primary key)
      - `order_id` (uuid, references orders)
      - `worker_id` (uuid, references workers)
      - `project_id` (uuid, references projects)
      - `status` (text, enum: pending, in_progress, completed, cancelled)
      - `created_at` (timestamptz)

  2. Views
    - `order_worker_details`: Provides aggregated view of orders with worker details

  3. Security
    - Enable RLS on order_workers table
    - Add policies for organization owners
*/

-- Drop existing view if it exists
DROP VIEW IF EXISTS order_worker_details;

-- Create order_workers table if it doesn't exist
CREATE TABLE IF NOT EXISTS order_workers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders ON DELETE CASCADE NOT NULL,
  worker_id uuid REFERENCES workers ON DELETE CASCADE NOT NULL,
  project_id uuid REFERENCES projects ON DELETE CASCADE NOT NULL,
  status text NOT NULL CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')) DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  UNIQUE(order_id, worker_id, project_id)
);

-- Enable RLS
ALTER TABLE order_workers ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_order_workers_order ON order_workers(order_id);
CREATE INDEX IF NOT EXISTS idx_order_workers_worker ON order_workers(worker_id);
CREATE INDEX IF NOT EXISTS idx_order_workers_project ON order_workers(project_id);
CREATE INDEX IF NOT EXISTS idx_order_workers_status ON order_workers(status);

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "organizations_owner_select_order_workers" ON order_workers;
DROP POLICY IF EXISTS "organizations_owner_insert_order_workers" ON order_workers;
DROP POLICY IF EXISTS "organizations_owner_update_order_workers" ON order_workers;
DROP POLICY IF EXISTS "organizations_owner_delete_order_workers" ON order_workers;

-- Create RLS policies for order_workers
CREATE POLICY "organizations_owner_select_order_workers"
  ON order_workers FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_workers.order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  );

CREATE POLICY "organizations_owner_insert_order_workers"
  ON order_workers FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  );

CREATE POLICY "organizations_owner_update_order_workers"
  ON order_workers FOR UPDATE
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

CREATE POLICY "organizations_owner_delete_order_workers"
  ON order_workers FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_workers.order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  );

-- Create view for order worker details
CREATE OR REPLACE VIEW order_worker_details AS
SELECT 
  o.*,
  json_agg(
    CASE WHEN ow.id IS NOT NULL THEN
      json_build_object(
        'id', ow.id,
        'worker_id', ow.worker_id,
        'worker_name', w.name,
        'project_id', ow.project_id,
        'project_name', p.name,
        'status', ow.status
      )
    ELSE NULL END
  ) FILTER (WHERE ow.id IS NOT NULL) as workers
FROM orders o
LEFT JOIN order_workers ow ON o.id = ow.order_id
LEFT JOIN workers w ON ow.worker_id = w.id
LEFT JOIN projects p ON ow.project_id = p.id
GROUP BY o.id;