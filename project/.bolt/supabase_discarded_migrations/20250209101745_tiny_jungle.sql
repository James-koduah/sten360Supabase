/*
  # Fix RLS Policies

  1. Changes
    - Drop existing policies safely
    - Recreate policies with proper checks
    - Ensure no duplicate policies

  2. Security
    - Maintain RLS on all tables
    - Add proper owner-based policies
*/

-- Safely drop existing policies
DO $$ 
BEGIN
  -- Organizations policies
  DROP POLICY IF EXISTS "organizations_select_policy" ON organizations;
  DROP POLICY IF EXISTS "organizations_insert_policy" ON organizations;
  DROP POLICY IF EXISTS "organizations_update_policy" ON organizations;
  DROP POLICY IF EXISTS "organizations_delete_policy" ON organizations;
  
  -- Workers policies
  DROP POLICY IF EXISTS "workers_select_policy" ON workers;
  DROP POLICY IF EXISTS "workers_insert_policy" ON workers;
  DROP POLICY IF EXISTS "workers_update_policy" ON workers;
  DROP POLICY IF EXISTS "workers_delete_policy" ON workers;
  DROP POLICY IF EXISTS "organizations_owner_select_workers" ON workers;
  DROP POLICY IF EXISTS "organizations_owner_insert_workers" ON workers;
  DROP POLICY IF EXISTS "organizations_owner_update_workers" ON workers;
  DROP POLICY IF EXISTS "organizations_owner_delete_workers" ON workers;
  
  -- Projects policies
  DROP POLICY IF EXISTS "organizations_owner_select_projects" ON projects;
  DROP POLICY IF EXISTS "organizations_owner_insert_projects" ON projects;
  DROP POLICY IF EXISTS "organizations_owner_update_projects" ON projects;
  DROP POLICY IF EXISTS "organizations_owner_delete_projects" ON projects;
  
  -- Worker project rates policies
  DROP POLICY IF EXISTS "organizations_owner_select_rates" ON worker_project_rates;
  DROP POLICY IF EXISTS "organizations_owner_insert_rates" ON worker_project_rates;
  DROP POLICY IF EXISTS "organizations_owner_update_rates" ON worker_project_rates;
  DROP POLICY IF EXISTS "organizations_owner_delete_rates" ON worker_project_rates;
  
  -- Tasks policies
  DROP POLICY IF EXISTS "organizations_owner_select_tasks" ON tasks;
  DROP POLICY IF EXISTS "organizations_owner_insert_tasks" ON tasks;
  DROP POLICY IF EXISTS "organizations_owner_update_tasks" ON tasks;
  DROP POLICY IF EXISTS "organizations_owner_delete_tasks" ON tasks;
  
  -- Deductions policies
  DROP POLICY IF EXISTS "organizations_owner_select_deductions" ON deductions;
  DROP POLICY IF EXISTS "organizations_owner_insert_deductions" ON deductions;
  DROP POLICY IF EXISTS "organizations_owner_update_deductions" ON deductions;
  DROP POLICY IF EXISTS "organizations_owner_delete_deductions" ON deductions;
END $$;

-- Create new policies for organizations
CREATE POLICY "owner_select_organizations"
  ON organizations FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "owner_insert_organizations"
  ON organizations FOR INSERT
  TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "owner_update_organizations"
  ON organizations FOR UPDATE
  TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "owner_delete_organizations"
  ON organizations FOR DELETE
  TO authenticated
  USING (owner_id = auth.uid());

-- Create new policies for workers
CREATE POLICY "owner_select_workers"
  ON workers FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = workers.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_insert_workers"
  ON workers FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_update_workers"
  ON workers FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = workers.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_delete_workers"
  ON workers FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = workers.organization_id
      AND owner_id = auth.uid()
    )
  );

-- Create new policies for projects
CREATE POLICY "owner_select_projects"
  ON projects FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = projects.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_insert_projects"
  ON projects FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_update_projects"
  ON projects FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = projects.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_delete_projects"
  ON projects FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = projects.organization_id
      AND owner_id = auth.uid()
    )
  );

-- Create new policies for worker_project_rates
CREATE POLICY "owner_select_rates"
  ON worker_project_rates FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_project_rates.worker_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_insert_rates"
  ON worker_project_rates FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_update_rates"
  ON worker_project_rates FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_project_rates.worker_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_delete_rates"
  ON worker_project_rates FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_project_rates.worker_id
      AND o.owner_id = auth.uid()
    )
  );

-- Create new policies for tasks
CREATE POLICY "owner_select_tasks"
  ON tasks FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = tasks.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_insert_tasks"
  ON tasks FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_update_tasks"
  ON tasks FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = tasks.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_delete_tasks"
  ON tasks FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = tasks.organization_id
      AND owner_id = auth.uid()
    )
  );

-- Create new policies for deductions
CREATE POLICY "owner_select_deductions"
  ON deductions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = deductions.task_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_insert_deductions"
  ON deductions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = task_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_update_deductions"
  ON deductions FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = deductions.task_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "owner_delete_deductions"
  ON deductions FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = deductions.task_id
      AND o.owner_id = auth.uid()
    )
  );