-- Create order_workers table to handle multiple workers per order
CREATE TABLE order_workers (
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

-- Create RLS policies for order_workers
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

-- Add indexes
CREATE INDEX idx_order_workers_order ON order_workers(order_id);
CREATE INDEX idx_order_workers_worker ON order_workers(worker_id);
CREATE INDEX idx_order_workers_project ON order_workers(project_id);
CREATE INDEX idx_order_workers_status ON order_workers(status);

-- Remove worker_id from orders table since it's now handled by order_workers
ALTER TABLE orders DROP COLUMN IF EXISTS worker_id;