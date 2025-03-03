/*
  # Clean up pro features

  This migration removes all pro-feature related tables and components from the database.

  1. Tables Removed:
    - task_comments
    - activity_logs
    - team_members

  2. Types Removed:
    - team_role
    - subscription_tier

  3. Columns Removed from organizations:
    - subscription_tier
    - subscription_status
    - trial_ends_at
    - features
    - max_team_members
    - max_workers
*/

-- First drop any existing policies that might depend on the tables or types
DROP POLICY IF EXISTS "Comment authors and admins can delete comments" ON task_comments;
DROP POLICY IF EXISTS "Team members can view comments" ON task_comments;
DROP POLICY IF EXISTS "Team members can add comments" ON task_comments;

-- Drop pro-feature tables in correct order (respecting dependencies)
DROP TABLE IF EXISTS task_comments;
DROP TABLE IF EXISTS activity_logs;
DROP TABLE IF EXISTS team_members;

-- Drop types after their dependent objects are gone
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