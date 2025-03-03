/*
  # Fix organization policies

  1. Changes
    - Remove existing problematic policies
    - Create new simplified policies for organizations table
    - Ensure proper access control for organization owners
  
  2. Security
    - Maintain row-level security
    - Restrict access to organization owners
    - Allow basic CRUD operations for authenticated users on their own organizations
*/

-- Drop existing policies individually to avoid loop syntax issues
DROP POLICY IF EXISTS "organizations_select_policy" ON organizations;
DROP POLICY IF EXISTS "organizations_insert_policy" ON organizations;
DROP POLICY IF EXISTS "organizations_update_policy" ON organizations;
DROP POLICY IF EXISTS "organizations_delete_policy" ON organizations;
DROP POLICY IF EXISTS "Users can view their own organizations" ON organizations;
DROP POLICY IF EXISTS "Only owners can update their organizations" ON organizations;
DROP POLICY IF EXISTS "Users can create organizations" ON organizations;
DROP POLICY IF EXISTS "Users can view their organizations" ON organizations;
DROP POLICY IF EXISTS "Users can create their organizations" ON organizations;
DROP POLICY IF EXISTS "Users can update their organizations" ON organizations;
DROP POLICY IF EXISTS "Users can delete their organizations" ON organizations;

-- Create new simplified policies
CREATE POLICY "organizations_select_policy"
  ON organizations
  FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "organizations_insert_policy"
  ON organizations
  FOR INSERT
  TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "organizations_update_policy"
  ON organizations
  FOR UPDATE
  TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "organizations_delete_policy"
  ON organizations
  FOR DELETE
  TO authenticated
  USING (owner_id = auth.uid());