/*
  # Fix organization members policies

  1. Changes
    - Remove recursive policy that was causing infinite recursion
    - Simplify organization members policies to use direct owner_id check
    - Add missing policies for organization members management
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Members can view organization members" ON organization_members;
DROP POLICY IF EXISTS "Organization owners can add members" ON organization_members;

-- Create new, simplified policies
CREATE POLICY "Users can view organization members"
  ON organization_members
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_members.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "Users can manage their organization members"
  ON organization_members
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_members.organization_id
      AND owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_members.organization_id
      AND owner_id = auth.uid()
    )
  );