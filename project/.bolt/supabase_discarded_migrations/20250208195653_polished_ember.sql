/*
  # Remove Pro Features
  
  1. Changes
    - Drop all pro-feature related tables
    - Drop all pro-feature related types
    - Remove subscription columns from organizations
    - Clean up any remaining pro-feature artifacts
*/

-- First drop policies that might depend on types
DROP POLICY IF EXISTS "Comment authors and admins can delete comments" ON task_comments;

-- Drop pro-feature tables in correct order
DROP TABLE IF EXISTS task_comments CASCADE;
DROP TABLE IF EXISTS activity_logs CASCADE;
DROP TABLE IF EXISTS team_members CASCADE;

-- Drop types after their dependent objects
DROP TYPE IF EXISTS team_role;
DROP TYPE IF EXISTS subscription_tier;

-- Remove pro-feature columns from organizations
ALTER TABLE organizations
DROP COLUMN IF EXISTS subscription_tier,
DROP COLUMN IF EXISTS subscription_status,
DROP COLUMN IF EXISTS trial_ends_at,
DROP COLUMN IF EXISTS features,
DROP COLUMN IF EXISTS max_team_members,
DROP COLUMN IF EXISTS max_workers;