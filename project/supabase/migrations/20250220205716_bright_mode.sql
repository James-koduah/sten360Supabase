-- Drop existing policies if they exist
DROP POLICY IF EXISTS "organizations_owner_manage_order_workers" ON order_workers;

-- Create order_workers table if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_workers') THEN
    -- Create order_workers table
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

    -- Create indexes
    CREATE INDEX IF NOT EXISTS idx_order_workers_order ON order_workers(order_id);
    CREATE INDEX IF NOT EXISTS idx_order_workers_worker ON order_workers(worker_id);
    CREATE INDEX IF NOT EXISTS idx_order_workers_project ON order_workers(project_id);
    CREATE INDEX IF NOT EXISTS idx_order_workers_status ON order_workers(status);
  END IF;
END $$;

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

-- Create function to automatically create tasks for order workers
CREATE OR REPLACE FUNCTION create_tasks_for_order_workers()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Create a task for the worker
  INSERT INTO tasks (
    organization_id,
    worker_id,
    project_id,
    description,
    date,
    status,
    amount
  )
  SELECT
    o.organization_id,
    NEW.worker_id,
    NEW.project_id,
    'Order: ' || o.order_number,
    CURRENT_DATE,
    'pending',
    wp.rate
  FROM orders o
  JOIN worker_project_rates wp ON wp.worker_id = NEW.worker_id AND wp.project_id = NEW.project_id
  WHERE o.id = NEW.order_id;

  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS create_tasks_on_order_worker ON order_workers;

-- Create trigger to create tasks when order workers are added
CREATE TRIGGER create_tasks_on_order_worker
  AFTER INSERT ON order_workers
  FOR EACH ROW
  EXECUTE FUNCTION create_tasks_for_order_workers();