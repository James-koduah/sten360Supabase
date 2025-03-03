/*
  # Add late_reason column to tasks table
  
  1. Changes
    - Add late_reason column to tasks table to track reasons for late task entries
    - Add index on late_reason for better query performance
*/

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tasks' AND column_name = 'late_reason'
  ) THEN
    ALTER TABLE tasks ADD COLUMN late_reason text;
    CREATE INDEX IF NOT EXISTS idx_tasks_late_reason ON tasks(late_reason);
  END IF;
END $$;