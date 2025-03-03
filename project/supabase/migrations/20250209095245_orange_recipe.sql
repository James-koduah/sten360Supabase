/*
  # Worker Management System Schema

  1. New Tables
    - `workers` - Stores worker information
      - `id` (uuid, primary key)
      - `organization_id` (uuid, foreign key)
      - `name` (text)
      - `whatsapp` (text)
      - `image` (text)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `projects` - Stores project information
      - `id` (uuid, primary key)
      - `organization_id` (uuid, foreign key)
      - `name` (text)
      - `description` (text)
      - `base_price` (numeric)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `worker_project_rates` - Stores worker-specific project rates
      - `id` (uuid, primary key)
      - `worker_id` (uuid, foreign key)
      - `project_id` (uuid, foreign key)
      - `rate` (numeric)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `tasks` - Stores task information
      - `id` (uuid, primary key)
      - `organization_id` (uuid, foreign key)
      - `worker_id` (uuid, foreign key)
      - `project_id` (uuid, foreign key)
      - `description` (text)
      - `date` (date)
      - `status` (text)
      - `amount` (numeric)
      - `completed_at` (timestamptz)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
      - `late_reason` (text)

    - `deductions` - Stores task deductions
      - `id` (uuid, primary key)
      - `task_id` (uuid, foreign key)
      - `amount` (numeric)
      - `reason` (text)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on all tables
    - Add policies for organization-based access
*/

-- Create workers table
CREATE TABLE IF NOT EXISTS workers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations NOT NULL,
  name text NOT NULL,
  whatsapp text,
  image text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create projects table
CREATE TABLE IF NOT EXISTS projects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations NOT NULL,
  name text NOT NULL,
  description text,
  base_price numeric(10,2) DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create worker_project_rates table
CREATE TABLE IF NOT EXISTS worker_project_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id uuid REFERENCES workers ON DELETE CASCADE NOT NULL,
  project_id uuid REFERENCES projects ON DELETE CASCADE NOT NULL,
  rate numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(worker_id, project_id)
);

-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations NOT NULL,
  worker_id uuid REFERENCES workers ON DELETE CASCADE NOT NULL,
  project_id uuid REFERENCES projects ON DELETE CASCADE NOT NULL,
  description text,
  date date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL CHECK (status IN ('pending', 'completed')) DEFAULT 'pending',
  amount numeric(10,2) NOT NULL DEFAULT 0,
  completed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  late_reason text
);

-- Create deductions table
CREATE TABLE IF NOT EXISTS deductions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid REFERENCES tasks ON DELETE CASCADE NOT NULL,
  amount numeric(10,2) NOT NULL DEFAULT 0,
  reason text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE worker_project_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE deductions ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_workers_organization ON workers(organization_id);
CREATE INDEX IF NOT EXISTS idx_projects_organization ON projects(organization_id);
CREATE INDEX IF NOT EXISTS idx_worker_project_rates_worker ON worker_project_rates(worker_id);
CREATE INDEX IF NOT EXISTS idx_worker_project_rates_project ON worker_project_rates(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_organization ON tasks(organization_id);
CREATE INDEX IF NOT EXISTS idx_tasks_worker ON tasks(worker_id);
CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_date ON tasks(date);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_deductions_task ON deductions(task_id);

-- Create RLS policies for workers
CREATE POLICY "organizations_owner_select_workers"
  ON workers FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = workers.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_insert_workers"
  ON workers FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_update_workers"
  ON workers FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = workers.organization_id
      AND owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_delete_workers"
  ON workers FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = workers.organization_id
      AND owner_id = auth.uid()
    )
  );

-- Create RLS policies for projects
CREATE POLICY "organizations_owner_select_projects"
  ON projects FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = projects.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_insert_projects"
  ON projects FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_update_projects"
  ON projects FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = projects.organization_id
      AND owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_delete_projects"
  ON projects FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = projects.organization_id
      AND owner_id = auth.uid()
    )
  );

-- Create RLS policies for worker_project_rates
CREATE POLICY "organizations_owner_select_rates"
  ON worker_project_rates FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_project_rates.worker_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_insert_rates"
  ON worker_project_rates FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_update_rates"
  ON worker_project_rates FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_project_rates.worker_id
      AND o.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_delete_rates"
  ON worker_project_rates FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN workers w ON w.organization_id = o.id
      WHERE w.id = worker_project_rates.worker_id
      AND o.owner_id = auth.uid()
    )
  );

-- Create RLS policies for tasks
CREATE POLICY "organizations_owner_select_tasks"
  ON tasks FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = tasks.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_insert_tasks"
  ON tasks FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_update_tasks"
  ON tasks FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = tasks.organization_id
      AND owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_delete_tasks"
  ON tasks FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = tasks.organization_id
      AND owner_id = auth.uid()
    )
  );

-- Create RLS policies for deductions
CREATE POLICY "organizations_owner_select_deductions"
  ON deductions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = deductions.task_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_insert_deductions"
  ON deductions FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = task_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_update_deductions"
  ON deductions FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = deductions.task_id
      AND o.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = task_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_delete_deductions"
  ON deductions FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN tasks t ON t.organization_id = o.id
      WHERE t.id = deductions.task_id
      AND o.owner_id = auth.uid()
    )
  );