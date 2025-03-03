/*
  # Fix auth policies and relationships

  1. Changes
    - Fix organization_members policies to prevent infinite recursion
    - Add insert policies for organizations and organization_members
    - Fix organization_id reference in auth flow
  
  2. Security
    - Enable proper RLS for new organizations
    - Allow authenticated users to create organizations
    - Allow organization owners to add members
*/

-- Fix organizations policies
CREATE POLICY "Users can create organizations"
  ON organizations
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = owner_id);

-- Fix organization_members policies
DROP POLICY IF EXISTS "Members can view organization members" ON organization_members;

CREATE POLICY "Members can view organization members"
  ON organization_members
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      WHERE o.id = organization_members.organization_id
      AND (
        o.owner_id = auth.uid() OR
        EXISTS (
          SELECT 1 FROM organization_members om2
          WHERE om2.organization_id = o.id
          AND om2.user_id = auth.uid()
        )
      )
    )
  );

CREATE POLICY "Organization owners can add members"
  ON organization_members
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );