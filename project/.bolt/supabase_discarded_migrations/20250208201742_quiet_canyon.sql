/*
  # Drop Pro Feature Tables

  This migration removes all pro-feature tables and components.

  1. Drop Tables:
    - task_comments
    - activity_logs
    - team_members
*/

-- First drop the actual tables
DROP TABLE IF EXISTS task_comments CASCADE;
DROP TABLE IF EXISTS activity_logs CASCADE;
DROP TABLE IF EXISTS team_members CASCADE;

-- Then drop any custom types
DROP TYPE IF EXISTS team_role CASCADE;
DROP TYPE IF EXISTS subscription_tier CASCADE;