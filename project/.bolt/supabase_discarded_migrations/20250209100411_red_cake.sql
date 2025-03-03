/*
  # Organization Schema Update

  1. New Columns
    - Add required columns to organizations table:
      - country (text)
      - city (text)
      - address (text)
      - employee_count (integer)
      - currency (text)

  2. Constraints
    - Add check constraint for employee_count to ensure it's positive
    - Add default values for currency and employee_count

  3. Indexes
    - Add indexes for better query performance
*/

-- Add new columns to organizations table
ALTER TABLE organizations 
ADD COLUMN IF NOT EXISTS country text,
ADD COLUMN IF NOT EXISTS city text,
ADD COLUMN IF NOT EXISTS address text,
ADD COLUMN IF NOT EXISTS employee_count integer DEFAULT 1,
ADD COLUMN IF NOT EXISTS currency text DEFAULT 'GHS';

-- Add check constraint for employee count
ALTER TABLE organizations 
ADD CONSTRAINT employee_count_positive 
CHECK (employee_count > 0);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_organizations_country ON organizations(country);
CREATE INDEX IF NOT EXISTS idx_organizations_city ON organizations(city);