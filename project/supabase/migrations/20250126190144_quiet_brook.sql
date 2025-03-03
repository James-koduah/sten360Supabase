/*
  # Fix workers table RLS policies

  1. Changes
    - Drop existing workers policies
    - Add new simplified policies for workers table that allow organization owners to manage workers
    - Add policies for viewing and managing worker data

  2. Security
    - Enable RLS on workers table
    - Add policies for organization owners to manage workers
    - Add policies for viewing worker data
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Organization members can view workers" ON workers;
DROP POLICY IF EXISTS "Organization admins can manage workers" ON workers;

-- Create new simplified policies
CREATE POLICY "organizations_owner_select_workers"
  ON workers
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = workers.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_insert_workers"
  ON workers
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_update_workers"
  ON workers
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = workers.organization_id
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

CREATE POLICY "organizations_owner_delete_workers"
  ON workers
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = workers.organization_id
      AND owner_id = auth.uid()
    )
  );