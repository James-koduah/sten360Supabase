/*
  # Add organization details and currency support

  1. Changes
    - Add country, city, address, employee_count, and currency columns to organizations table
    - Add default currency value (GHS)
    - Add check constraint for employee count
    - Add index for country and city for faster lookups

  2. Notes
    - Currency codes follow ISO 4217 standard
    - Employee count must be positive
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