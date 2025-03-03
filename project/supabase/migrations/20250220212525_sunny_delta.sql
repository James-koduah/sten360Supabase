/*
  # Fix Order Details View

  1. Changes
    - Drop existing order_details view
    - Create new view with correct worker relationships through order_workers table
    - Add proper aggregation for services and custom fields
*/

-- Drop existing view if it exists
DROP VIEW IF EXISTS order_details;

-- Create a new view for orders with all their relationships
CREATE OR REPLACE VIEW order_details AS
SELECT 
  o.*,
  c.name as client_name,
  json_agg(
    CASE WHEN ow.id IS NOT NULL THEN
      json_build_object(
        'id', ow.id,
        'worker_id', ow.worker_id,
        'worker_name', w.name,
        'project_id', ow.project_id,
        'project_name', p.name,
        'status', ow.status
      )
    ELSE NULL END
  ) FILTER (WHERE ow.id IS NOT NULL) as workers,
  json_agg(
    CASE WHEN os.id IS NOT NULL THEN
      json_build_object(
        'id', os.id,
        'service_id', os.service_id,
        'service_name', s.name,
        'quantity', os.quantity,
        'cost', os.cost
      )
    ELSE NULL END
  ) FILTER (WHERE os.id IS NOT NULL) as services,
  json_agg(
    CASE WHEN ocf.id IS NOT NULL THEN
      json_build_object(
        'id', ocf.id,
        'field_id', ccf.id,
        'field_title', ccf.title,
        'field_value', ccf.value
      )
    ELSE NULL END
  ) FILTER (WHERE ocf.id IS NOT NULL) as custom_fields
FROM orders o
LEFT JOIN clients c ON c.id = o.client_id
LEFT JOIN order_workers ow ON ow.order_id = o.id
LEFT JOIN workers w ON w.id = ow.worker_id
LEFT JOIN projects p ON p.id = ow.project_id
LEFT JOIN order_services os ON os.order_id = o.id
LEFT JOIN services s ON s.id = os.service_id
LEFT JOIN order_custom_fields ocf ON ocf.order_id = o.id
LEFT JOIN client_custom_fields ccf ON ccf.id = ocf.field_id
GROUP BY o.id, c.name;