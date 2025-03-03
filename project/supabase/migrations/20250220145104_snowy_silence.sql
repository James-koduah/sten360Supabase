/*
  # Fix task status functionality

  1. Changes
    - Drop existing task_status_check constraint
    - Add new constraint with correct status values
    - Update existing tasks to use new status values
*/

-- Drop the existing constraint
ALTER TABLE tasks
DROP CONSTRAINT IF EXISTS task_status_check;

-- Add the new constraint with correct status values
ALTER TABLE tasks
ADD CONSTRAINT task_status_check 
CHECK (status IN ('pending', 'in_progress', 'delayed', 'completed'));

-- Update any existing tasks with old status values
UPDATE tasks 
SET status = 'pending'
WHERE status NOT IN ('pending', 'in_progress', 'delayed', 'completed');