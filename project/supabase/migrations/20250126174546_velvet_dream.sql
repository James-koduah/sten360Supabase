/*
  # Initial Schema Setup for Multi-tenant SaaS Application

  1. New Tables
    - `organizations`
      - `id` (uuid, primary key)
      - `name` (text)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
      - `owner_id` (uuid, references auth.users)
      - `subscription_tier` (text)
      - `subscription_status` (text)
      
    - `organization_members`
      - `id` (uuid, primary key)
      - `organization_id` (uuid, references organizations)
      - `user_id` (uuid, references auth.users)
      - `role` (text)
      - `created_at` (timestamp)
      
    - `workers` (existing table modified for multi-tenancy)
      - Added `organization_id` (uuid, references organizations)
      
    - `projects` (existing table modified for multi-tenancy)
      - Added `organization_id` (uuid, references organizations)
      
    - `tasks` (existing table modified for multi-tenancy)
      - Added `organization_id` (uuid, references organizations)

  2. Security
    - Enable RLS on all tables
    - Add policies for organization-based access control
    - Set up authentication policies
*/

-- Create organizations table
CREATE TABLE organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  owner_id uuid REFERENCES auth.users NOT NULL,
  subscription_tier text DEFAULT 'free',
  subscription_status text DEFAULT 'active',
  UNIQUE(owner_id, name)
);

ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;

-- Create organization members table
CREATE TABLE organization_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations NOT NULL,
  user_id uuid REFERENCES auth.users NOT NULL,
  role text NOT NULL CHECK (role IN ('owner', 'admin', 'member')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(organization_id, user_id)
);

ALTER TABLE organization_members ENABLE ROW LEVEL SECURITY;

-- Create workers table with organization support
CREATE TABLE workers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations NOT NULL,
  name text NOT NULL,
  whatsapp text,
  image text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE workers ENABLE ROW LEVEL SECURITY;

-- Create projects table
CREATE TABLE projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations NOT NULL,
  name text NOT NULL,
  description text,
  base_price numeric(10,2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

-- Create worker_project_rates table
CREATE TABLE worker_project_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id uuid REFERENCES workers NOT NULL,
  project_id uuid REFERENCES projects NOT NULL,
  rate numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(worker_id, project_id)
);

ALTER TABLE worker_project_rates ENABLE ROW LEVEL SECURITY;

-- Create tasks table
CREATE TABLE tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations NOT NULL,
  worker_id uuid REFERENCES workers NOT NULL,
  project_id uuid REFERENCES projects NOT NULL,
  description text,
  date date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL CHECK (status IN ('pending', 'completed')) DEFAULT 'pending',
  amount numeric(10,2) NOT NULL DEFAULT 0,
  completed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Create deductions table
CREATE TABLE deductions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid REFERENCES tasks NOT NULL,
  amount numeric(10,2) NOT NULL DEFAULT 0,
  reason text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE deductions ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Organizations policies
CREATE POLICY "Users can view their own organizations"
  ON organizations
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = owner_id OR 
    EXISTS (
      SELECT 1 FROM organization_members 
      WHERE organization_id = organizations.id 
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Only owners can update their organizations"
  ON organizations
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- Organization members policies
CREATE POLICY "Members can view organization members"
  ON organization_members
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      WHERE om.organization_id = organization_members.organization_id
      AND om.user_id = auth.uid()
    )
  );

-- Workers policies
CREATE POLICY "Organization members can view workers"
  ON workers
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organization_members
      WHERE organization_id = workers.organization_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Organization admins can manage workers"
  ON workers
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organization_members
      WHERE organization_id = workers.organization_id
      AND user_id = auth.uid()
      AND role IN ('owner', 'admin')
    )
  );

-- Projects policies
CREATE POLICY "Organization members can view projects"
  ON projects
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organization_members
      WHERE organization_id = projects.organization_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Organization admins can manage projects"
  ON projects
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organization_members
      WHERE organization_id = projects.organization_id
      AND user_id = auth.uid()
      AND role IN ('owner', 'admin')
    )
  );

-- Worker project rates policies
CREATE POLICY "Organization members can view rates"
  ON worker_project_rates
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      JOIN workers w ON w.organization_id = om.organization_id
      WHERE w.id = worker_project_rates.worker_id
      AND om.user_id = auth.uid()
    )
  );

-- Tasks policies
CREATE POLICY "Organization members can view tasks"
  ON tasks
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organization_members
      WHERE organization_id = tasks.organization_id
      AND user_id = auth.uid()
    )
  );

CREATE POLICY "Organization members can manage tasks"
  ON tasks
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organization_members
      WHERE organization_id = tasks.organization_id
      AND user_id = auth.uid()
    )
  );

-- Deductions policies
CREATE POLICY "Organization members can view deductions"
  ON deductions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      JOIN tasks t ON t.organization_id = om.organization_id
      WHERE t.id = deductions.task_id
      AND om.user_id = auth.uid()
    )
  );

CREATE POLICY "Organization admins can manage deductions"
  ON deductions
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organization_members om
      JOIN tasks t ON t.organization_id = om.organization_id
      WHERE t.id = deductions.task_id
      AND om.user_id = auth.uid()
      AND om.role IN ('owner', 'admin')
    )
  );