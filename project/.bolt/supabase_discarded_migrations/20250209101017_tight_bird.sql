/*
  # Organization Schema Update

  1. Tables
    - Add organization details columns
    - Add constraints and defaults
    - Add indexes for performance

  2. Changes
    - Add country, city, address fields
    - Add employee count with validation
    - Add currency with default
*/

-- Drop existing constraint if it exists
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM pg_constraint 
    WHERE conname = 'employee_count_positive'
  ) THEN
    ALTER TABLE organizations DROP CONSTRAINT employee_count_positive;
  END IF;
END $$;

-- Drop existing columns if they exist
DO $$ 
BEGIN
  ALTER TABLE organizations 
    DROP COLUMN IF EXISTS country,
    DROP COLUMN IF EXISTS city,
    DROP COLUMN IF EXISTS address,
    DROP COLUMN IF EXISTS employee_count,
    DROP COLUMN IF EXISTS currency;
END $$;

-- Add new columns with proper defaults and constraints
ALTER TABLE organizations 
  ADD COLUMN country text,
  ADD COLUMN city text,
  ADD COLUMN address text,
  ADD COLUMN employee_count integer DEFAULT 1,
  ADD COLUMN currency text DEFAULT 'GHS';

-- Add check constraint for employee count
ALTER TABLE organizations 
  ADD CONSTRAINT employee_count_positive 
  CHECK (employee_count > 0);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_organizations_country ON organizations(country);
CREATE INDEX IF NOT EXISTS idx_organizations_city ON organizations(city);

-- Update RLS policies
DROP POLICY IF EXISTS "organizations_select_policy" ON organizations;
DROP POLICY IF EXISTS "organizations_insert_policy" ON organizations;
DROP POLICY IF EXISTS "organizations_update_policy" ON organizations;
DROP POLICY IF EXISTS "organizations_delete_policy" ON organizations;

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