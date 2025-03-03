/*
  # Reset Database Schema
  
  1. Changes
    - Drop all existing tables
    - Create fresh tables with proper constraints
    - Set up RLS policies
    
  2. Security
    - Enable RLS on all tables
    - Add proper owner-based policies
*/

-- First, drop all existing tables in the correct order
DROP TABLE IF EXISTS deductions CASCADE;
DROP TABLE IF EXISTS tasks CASCADE;
DROP TABLE IF EXISTS worker_project_rates CASCADE;
DROP TABLE IF EXISTS projects CASCADE;
DROP TABLE IF EXISTS workers CASCADE;
DROP TABLE IF EXISTS organizations CASCADE;

-- Create organizations table
CREATE TABLE organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  country text,
  city text,
  address text,
  employee_count integer DEFAULT 1,
  currency text DEFAULT 'GHS',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  owner_id uuid REFERENCES auth.users NOT NULL,
  CONSTRAINT employee_count_positive CHECK (employee_count > 0)
);

-- Create workers table
CREATE TABLE workers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  whatsapp text,
  image text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create projects table
CREATE TABLE projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  description text,
  base_price numeric(10,2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create worker_project_rates table
CREATE TABLE worker_project_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id uuid REFERENCES workers ON DELETE CASCADE NOT NULL,
  project_id uuid REFERENCES projects ON DELETE CASCADE NOT NULL,
  rate numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(worker_id, project_id)
);

-- Create tasks table
CREATE TABLE tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations ON DELETE CASCADE NOT NULL,
  worker_id uuid REFERENCES workers ON DELETE CASCADE NOT NULL,
  project_id uuid REFERENCES projects ON DELETE CASCADE NOT NULL,
  description text,
  date date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL CHECK (status IN ('pending', 'completed')) DEFAULT 'pending',
  amount numeric(10,2) NOT NULL DEFAULT 0,
  completed_at timestamptz,
  late_reason text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create deductions table
CREATE TABLE deductions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid REFERENCES tasks ON DELETE CASCADE NOT NULL,
  amount numeric(10,2) NOT NULL DEFAULT 0,
  reason text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_project_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE deductions ENABLE ROW LEVEL SECURITY;

-- Create indexes for better performance
CREATE INDEX idx_organizations_owner ON organizations(owner_id);
CREATE INDEX idx_organizations_country ON organizations(country);
CREATE INDEX idx_organizations_city ON organizations(city);
CREATE INDEX idx_workers_organization ON workers(organization_id);
CREATE INDEX idx_projects_organization ON projects(organization_id);
CREATE INDEX idx_worker_project_rates_worker ON worker_project_rates(worker_id);
CREATE INDEX idx_worker_project_rates_project ON worker_project_rates(project_id);
CREATE INDEX idx_tasks_organization ON tasks(organization_id);
CREATE INDEX idx_tasks_worker ON tasks(worker_id);
CREATE INDEX idx_tasks_project ON tasks(project_id);
CREATE INDEX idx_tasks_date ON tasks(date);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_deductions_task ON deductions(task_id);

-- Create RLS policies for organizations
CREATE POLICY "owner_organizations"
  ON organizations
  USING (owner_id = auth.uid());

-- Create RLS policies for workers
CREATE POLICY "owner_workers"
  ON workers
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

-- Create RLS policies for projects
CREATE POLICY "owner_projects"
  ON projects
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

-- Create RLS policies for worker_project_rates
CREATE POLICY "owner_rates"
  ON worker_project_rates
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_id
      AND o.owner_id = auth.uid()
    )
  );

-- Create RLS policies for tasks
CREATE POLICY "owner_tasks"
  ON tasks
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

-- Create RLS policies for deductions
CREATE POLICY "owner_deductions"
  ON deductions
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = task_id
      AND o.owner_id = auth.uid()
    )
  );