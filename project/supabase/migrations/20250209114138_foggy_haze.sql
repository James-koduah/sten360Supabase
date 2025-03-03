/*
  # Add organization setup fields
  
  1. New Fields
    - country (text)
    - city (text)
    - address (text)
    - employee_count (integer)
    - currency (text)
    
  2. Indexes
    - country and city for better query performance
*/

-- Add new columns to organizations table
ALTER TABLE organizations 
ADD COLUMN IF NOT EXISTS country text,
ADD COLUMN IF NOT EXISTS city text,
ADD COLUMN IF NOT EXISTS address text,
ADD COLUMN IF NOT EXISTS employee_count integer,
ADD COLUMN IF NOT EXISTS currency text DEFAULT 'GHS';

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_organizations_country ON organizations(country);
CREATE INDEX IF NOT EXISTS idx_organizations_city ON organizations(city);