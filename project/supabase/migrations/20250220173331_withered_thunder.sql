-- Drop existing policies
DROP POLICY IF EXISTS "organizations_owner_select_projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_insert_projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_update_projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_delete_projects" ON projects;

-- Create a single policy for all operations
CREATE POLICY "organizations_owner_manage_projects"
  ON projects
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