-- Drop existing project policies
DROP POLICY IF EXISTS "organizations_owner_select_projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_insert_projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_update_projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_delete_projects" ON projects;

-- Create new simplified project policies
CREATE POLICY "organizations_owner_select_projects"
  ON projects FOR SELECT
  TO authenticated
  USING (organization_id IN (
    SELECT id FROM organizations WHERE owner_id = auth.uid()
  ));

CREATE POLICY "organizations_owner_insert_projects"
  ON projects FOR INSERT
  TO authenticated
  WITH CHECK (organization_id IN (
    SELECT id FROM organizations WHERE owner_id = auth.uid()
  ));

CREATE POLICY "organizations_owner_update_projects"
  ON projects FOR UPDATE
  TO authenticated
  USING (organization_id IN (
    SELECT id FROM organizations WHERE owner_id = auth.uid()
  ))
  WITH CHECK (organization_id IN (
    SELECT id FROM organizations WHERE owner_id = auth.uid()
  ));

CREATE POLICY "organizations_owner_delete_projects"
  ON projects FOR DELETE
  TO authenticated
  USING (organization_id IN (
    SELECT id FROM organizations WHERE owner_id = auth.uid()
  ));