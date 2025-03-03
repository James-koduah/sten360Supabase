/*
  # Worker Project Rates RLS Policies

  1. Security
    - Add policies for organization owners to manage worker project rates
    - Ensure proper access control through organization ownership
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Organization members can view rates" ON worker_project_rates;
DROP POLICY IF EXISTS "organizations_owner_select_rates" ON worker_project_rates;
DROP POLICY IF EXISTS "organizations_owner_insert_rates" ON worker_project_rates;
DROP POLICY IF EXISTS "organizations_owner_update_rates" ON worker_project_rates;
DROP POLICY IF EXISTS "organizations_owner_delete_rates" ON worker_project_rates;

-- Create new policies
CREATE POLICY "organizations_owner_select_rates"
  ON worker_project_rates
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_project_rates.worker_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_insert_rates"
  ON worker_project_rates
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_update_rates"
  ON worker_project_rates
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_project_rates.worker_id
      AND o.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_delete_rates"
  ON worker_project_rates
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_project_rates.worker_id
      AND o.owner_id = auth.uid()
    )
  );