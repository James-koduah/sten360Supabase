/*
  # Fix task creation for orders

  1. Changes
    - Update task creation trigger to handle multiple workers
    - Add status_changed_at when creating tasks
    - Add proper task description with order number
*/

-- Drop existing function and trigger
DROP TRIGGER IF EXISTS create_tasks_on_order_worker ON order_workers;
DROP FUNCTION IF EXISTS create_tasks_for_order_workers();

-- Create improved function to handle task creation
CREATE OR REPLACE FUNCTION create_tasks_for_order_workers()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Create a task for the worker
  INSERT INTO tasks (
    organization_id,
    worker_id,
    project_id,
    description,
    date,
    status,
    status_changed_at,
    amount
  )
  SELECT
    o.organization_id,
    NEW.worker_id,
    NEW.project_id,
    CASE 
      WHEN o.description IS NOT NULL AND o.description != '' 
      THEN 'Order ' || o.order_number || ': ' || o.description
      ELSE 'Order ' || o.order_number
    END,
    COALESCE(o.due_date, CURRENT_DATE),
    'pending',
    now(),
    wp.rate
  FROM orders o
  JOIN worker_project_rates wp ON wp.worker_id = NEW.worker_id AND wp.project_id = NEW.project_id
  WHERE o.id = NEW.order_id;

  RETURN NEW;
END;
$$;

-- Create new trigger
CREATE TRIGGER create_tasks_on_order_worker
  AFTER INSERT ON order_workers
  FOR EACH ROW
  EXECUTE FUNCTION create_tasks_for_order_workers();