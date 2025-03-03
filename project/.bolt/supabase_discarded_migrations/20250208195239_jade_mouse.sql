/*
  # Clean up subscription and pro features
  
  1. Changes
    - Remove subscription-related columns from organizations table
    - Clean up unused indexes and constraints
    - Ensure proper cascade deletes
*/

-- First check and drop trigger if it exists
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'set_organization_limits_trigger'
  ) THEN
    DROP TRIGGER set_organization_limits_trigger ON organizations;
  END IF;
END $$;

-- Drop function if it exists
DROP FUNCTION IF EXISTS set_organization_limits();

-- Remove pro-feature columns from organizations
ALTER TABLE organizations
DROP COLUMN IF EXISTS subscription_tier,
DROP COLUMN IF EXISTS subscription_status,
DROP COLUMN IF EXISTS trial_ends_at,
DROP COLUMN IF EXISTS features,
DROP COLUMN IF EXISTS max_team_members,
DROP COLUMN IF EXISTS max_workers;

-- Drop types if they exist
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'team_role') THEN
    DROP TYPE team_role;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_tier') THEN
    DROP TYPE subscription_tier;
  END IF;
END $$;

-- Drop function and triggers if they exist
DROP FUNCTION IF EXISTS log_activity() CASCADE;

DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'log_tasks_activity'
  ) THEN
    DROP TRIGGER log_tasks_activity ON tasks;
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'log_workers_activity'
  ) THEN
    DROP TRIGGER log_workers_activity ON workers;
  END IF;
END $$;

-- Ensure core tables have proper indexes
CREATE INDEX IF NOT EXISTS idx_workers_organization_id ON workers(organization_id);
CREATE INDEX IF NOT EXISTS idx_projects_organization_id ON projects(organization_id);
CREATE INDEX IF NOT EXISTS idx_tasks_organization_id ON tasks(organization_id);
CREATE INDEX IF NOT EXISTS idx_tasks_worker_id ON tasks(worker_id);
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_date ON tasks(date);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_deductions_task_id ON deductions(task_id);

-- Ensure proper cascade deletes
ALTER TABLE tasks
DROP CONSTRAINT IF EXISTS tasks_worker_id_fkey,
DROP CONSTRAINT IF EXISTS tasks_project_id_fkey,
ADD CONSTRAINT tasks_worker_id_fkey
  FOREIGN KEY (worker_id)
  REFERENCES workers(id)
  ON DELETE CASCADE,
ADD CONSTRAINT tasks_project_id_fkey
  FOREIGN KEY (project_id)
  REFERENCES projects(id)
  ON DELETE CASCADE;

ALTER TABLE deductions
DROP CONSTRAINT IF EXISTS deductions_task_id_fkey,
ADD CONSTRAINT deductions_task_id_fkey
  FOREIGN KEY (task_id)
  REFERENCES tasks(id)
  ON DELETE CASCADE;