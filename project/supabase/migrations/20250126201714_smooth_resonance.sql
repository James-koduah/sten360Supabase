/*
  # Add timestamps and improve tasks table

  1. Changes
    - Add created_at timestamp to tasks if it doesn't exist
    - Add indexes for better performance
    
  2. Notes
    - Skipping deductions table and policies as they already exist
    - Only adding missing columns and indexes
*/

-- Add created_at to tasks if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tasks' AND column_name = 'created_at'
  ) THEN
    ALTER TABLE tasks ADD COLUMN created_at timestamptz DEFAULT now();
  END IF;
END $$;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_tasks_worker_id ON tasks(worker_id);
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_organization_id ON tasks(organization_id);
CREATE INDEX IF NOT EXISTS idx_tasks_date ON tasks(date);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);
CREATE INDEX IF NOT EXISTS idx_tasks_completed_at ON tasks(completed_at);