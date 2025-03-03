/*
  # Fix task status functionality

  1. Changes
    - Drop existing task_status_check constraint
    - Add new constraint with correct status values
    - Update existing tasks to use new status values
    - Add status_changed_at and delay_reason columns if not exists
*/

-- Drop the existing constraint
ALTER TABLE tasks
DROP CONSTRAINT IF EXISTS tasks_status_check;

-- Add new columns if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tasks' AND column_name = 'status_changed_at'
  ) THEN
    ALTER TABLE tasks ADD COLUMN status_changed_at timestamptz DEFAULT now();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tasks' AND column_name = 'delay_reason'
  ) THEN
    ALTER TABLE tasks ADD COLUMN delay_reason text;
  END IF;
END $$;

-- Add the new constraint with correct status values
ALTER TABLE tasks
ADD CONSTRAINT tasks_status_check 
CHECK (status IN ('pending', 'in_progress', 'delayed', 'completed'));

-- Update any existing tasks with old status values
UPDATE tasks 
SET status = 'pending'
WHERE status NOT IN ('pending', 'in_progress', 'delayed', 'completed');

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_status_changed_at ON tasks(status_changed_at);