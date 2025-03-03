/*
  # Clean Pro Features

  This migration removes all pro-feature tables, types, and columns in the correct order to avoid dependency issues.
*/

-- First drop policies that depend on types
DROP POLICY IF EXISTS "Comment authors and admins can delete comments" ON task_comments;

-- Drop pro-feature tables in correct order (respecting dependencies)
DROP TABLE IF EXISTS task_comments CASCADE;
DROP TABLE IF EXISTS activity_logs CASCADE;
DROP TABLE IF EXISTS team_members CASCADE;

-- Now safe to drop types since dependent objects are gone
DROP TYPE IF EXISTS team_role;
DROP TYPE IF EXISTS subscription_tier;

-- Finally remove pro-feature columns from organizations
ALTER TABLE organizations 
DROP COLUMN IF EXISTS subscription_tier,
DROP COLUMN IF EXISTS subscription_status,
DROP COLUMN IF EXISTS trial_ends_at,
DROP COLUMN IF EXISTS features,
DROP COLUMN IF EXISTS max_team_members,
DROP COLUMN IF EXISTS max_workers;