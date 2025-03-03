/*
  # Fix tasks and projects schema

  1. Changes
    - Add cascade delete for tasks when worker is deleted
    - Add cascade delete for deductions when task is deleted
    - Add cascade delete for worker_project_rates when project is deleted
    - Add cascade delete for tasks when project is deleted
    - Fix tasks foreign key references
    - Add missing indexes for better query performance

  2. Security
    - Add policies for tasks and deductions
*/

-- Fix tasks foreign key references with cascade delete
ALTER TABLE tasks
DROP CONSTRAINT IF EXISTS tasks_worker_id_fkey,
DROP CONSTRAINT IF EXISTS tasks_project_id_fkey,
ADD CONSTRAINT tasks_worker_id_fkey
  FOREIGN KEY (worker_id)
  REFERENCES workers(id)
  ON DELETE CASCADE,
ADD CONSTRAINT tasks_project_id_fkey
  FOREIGN KEY (project_id)
  REFERENCES projects(id)
  ON DELETE CASCADE;

-- Fix deductions foreign key reference with cascade delete
ALTER TABLE deductions
DROP CONSTRAINT IF EXISTS deductions_task_id_fkey,
ADD CONSTRAINT deductions_task_id_fkey
  FOREIGN KEY (task_id)
  REFERENCES tasks(id)
  ON DELETE CASCADE;

-- Fix worker_project_rates foreign key references with cascade delete
ALTER TABLE worker_project_rates
DROP CONSTRAINT IF EXISTS worker_project_rates_worker_id_fkey,
DROP CONSTRAINT IF EXISTS worker_project_rates_project_id_fkey,
ADD CONSTRAINT worker_project_rates_worker_id_fkey
  FOREIGN KEY (worker_id)
  REFERENCES workers(id)
  ON DELETE CASCADE,
ADD CONSTRAINT worker_project_rates_project_id_fkey
  FOREIGN KEY (project_id)
  REFERENCES projects(id)
  ON DELETE CASCADE;

-- Add missing indexes
CREATE INDEX IF NOT EXISTS tasks_worker_id_idx ON tasks(worker_id);
CREATE INDEX IF NOT EXISTS tasks_project_id_idx ON tasks(project_id);
CREATE INDEX IF NOT EXISTS tasks_organization_id_idx ON tasks(organization_id);
CREATE INDEX IF NOT EXISTS deductions_task_id_idx ON deductions(task_id);
CREATE INDEX IF NOT EXISTS worker_project_rates_worker_id_idx ON worker_project_rates(worker_id);
CREATE INDEX IF NOT EXISTS worker_project_rates_project_id_idx ON worker_project_rates(project_id);

-- Drop existing task policies
DROP POLICY IF EXISTS "Organization members can view tasks" ON tasks;
DROP POLICY IF EXISTS "Organization members can manage tasks" ON tasks;

-- Create new task policies
CREATE POLICY "organizations_owner_select_tasks"
  ON tasks
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = tasks.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_insert_tasks"
  ON tasks
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_update_tasks"
  ON tasks
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = tasks.organization_id
      AND owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_delete_tasks"
  ON tasks
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = tasks.organization_id
      AND owner_id = auth.uid()
    )
  );

-- Drop existing deduction policies
DROP POLICY IF EXISTS "Organization members can view deductions" ON deductions;
DROP POLICY IF EXISTS "Organization admins can manage deductions" ON deductions;

-- Create new deduction policies
CREATE POLICY "organizations_owner_select_deductions"
  ON deductions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = deductions.task_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_insert_deductions"
  ON deductions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = task_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_update_deductions"
  ON deductions
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = deductions.task_id
      AND o.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = task_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_delete_deductions"
  ON deductions
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = deductions.task_id
      AND o.owner_id = auth.uid()
    )
  );