-- First ensure proper cascade delete is set up
ALTER TABLE worker_project_rates
DROP CONSTRAINT IF EXISTS worker_project_rates_project_id_fkey,
ADD CONSTRAINT worker_project_rates_project_id_fkey
  FOREIGN KEY (project_id)
  REFERENCES projects(id)
  ON DELETE CASCADE;

-- Drop existing policies
DROP POLICY IF EXISTS "organizations_owner_select_projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_insert_projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_update_projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_delete_projects" ON projects;

-- Create new simplified project policies with direct organization check
CREATE POLICY "organizations_owner_manage_projects"
  ON projects
  USING (organization_id IN (
    SELECT id FROM organizations WHERE owner_id = auth.uid()
  ))
  WITH CHECK (organization_id IN (
    SELECT id FROM organizations WHERE owner_id = auth.uid()
  ));