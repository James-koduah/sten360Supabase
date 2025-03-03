-- Create deductions table if it doesn't exist
CREATE TABLE IF NOT EXISTS deductions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id uuid REFERENCES tasks ON DELETE CASCADE,
  amount numeric(10,2) NOT NULL DEFAULT 0,
  reason text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS if not already enabled
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'deductions' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE deductions ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_deductions_task_id ON deductions(task_id);
CREATE INDEX IF NOT EXISTS idx_deductions_created_at ON deductions(created_at);