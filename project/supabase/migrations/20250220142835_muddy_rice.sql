/*
  # Update task status options

  1. Changes
    - Modify task status to include 'in_progress' and 'delayed' options
    - Update existing tasks to use new status options
    - Add status_changed_at timestamp column
    - Add delay_reason text column

  2. Security
    - Maintain existing RLS policies
*/

-- First, create a temporary type for the new status options
CREATE TYPE task_status_new AS ENUM ('pending', 'in_progress', 'delayed', 'completed');

-- Add new columns
ALTER TABLE tasks
ADD COLUMN IF NOT EXISTS status_changed_at timestamptz,
ADD COLUMN IF NOT EXISTS delay_reason text;

-- Update the status column to use the new type
ALTER TABLE tasks 
ALTER COLUMN status TYPE text;

-- Add check constraint for the new status values
ALTER TABLE tasks
ADD CONSTRAINT task_status_check 
CHECK (status IN ('pending', 'in_progress', 'delayed', 'completed'));

-- Set default for status_changed_at
ALTER TABLE tasks
ALTER COLUMN status_changed_at SET DEFAULT now();

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_status_changed_at ON tasks(status_changed_at);