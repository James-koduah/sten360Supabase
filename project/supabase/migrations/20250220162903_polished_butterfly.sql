/*
  # Update client custom fields to support text and file uploads

  1. Changes
    - Add type column to client_custom_fields table to distinguish between text and file entries
    - Add check constraint to ensure valid types
    - Add indexes for better performance

  2. Security
    - Maintain existing RLS policies
*/

-- Add type column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'client_custom_fields' AND column_name = 'type'
  ) THEN
    ALTER TABLE client_custom_fields 
    ADD COLUMN type text NOT NULL DEFAULT 'text';
  END IF;
END $$;

-- Add check constraint for valid types
ALTER TABLE client_custom_fields
DROP CONSTRAINT IF EXISTS client_custom_fields_type_check;

ALTER TABLE client_custom_fields
ADD CONSTRAINT client_custom_fields_type_check
CHECK (type IN ('text', 'file'));

-- Create index for type column
CREATE INDEX IF NOT EXISTS idx_client_custom_fields_type 
ON client_custom_fields(type);

-- Update any existing records to have 'text' type
UPDATE client_custom_fields
SET type = 'text'
WHERE type NOT IN ('text', 'file');