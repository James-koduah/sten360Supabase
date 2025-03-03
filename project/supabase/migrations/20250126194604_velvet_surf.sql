/*
  # Project RLS Policies

  1. Security
    - Enable RLS on projects table
    - Add policies for organization owners to manage projects
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Organization members can view projects" ON projects;
DROP POLICY IF EXISTS "Organization admins can manage projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_select_projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_insert_projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_update_projects" ON projects;
DROP POLICY IF EXISTS "organizations_owner_delete_projects" ON projects;

-- Create new simplified policies
CREATE POLICY "organizations_owner_select_projects"
  ON projects
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = projects.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_insert_projects"
  ON projects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_update_projects"
  ON projects
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = projects.organization_id
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

CREATE POLICY "organizations_owner_delete_projects"
  ON projects
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = projects.organization_id
      AND owner_id = auth.uid()
    )
  );