/*
  # Safe Organization Schema Update

  1. Safely add constraint
    - Add employee_count constraint only if it doesn't exist
    - Use DO block to handle conditional constraint creation
*/

DO $$ 
BEGIN
  -- Check if the constraint already exists
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_constraint 
    WHERE conname = 'employee_count_positive'
  ) THEN
    -- Add the constraint only if it doesn't exist
    ALTER TABLE organizations 
    ADD CONSTRAINT employee_count_positive 
    CHECK (employee_count > 0);
  END IF;
END $$;