-- Grant schema usage
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;

-- Grant table permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, authenticated;

-- Ensure RLS is enabled on all relevant tables
ALTER TABLE IF EXISTS orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS order_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS order_custom_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS order_workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS services ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies first to avoid conflicts
DROP POLICY IF EXISTS "owner_manage_orders" ON orders;
DROP POLICY IF EXISTS "owner_manage_order_services" ON order_services;
DROP POLICY IF EXISTS "owner_manage_order_custom_fields" ON order_custom_fields;
DROP POLICY IF EXISTS "owner_manage_order_workers" ON order_workers;
DROP POLICY IF EXISTS "owner_manage_services" ON services;

-- Create new simplified policies
CREATE POLICY "owner_manage_orders"
  ON orders
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid()));

CREATE POLICY "owner_manage_order_services"
  ON order_services
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = order_id
    AND o.organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid())
  ));

CREATE POLICY "owner_manage_order_custom_fields"
  ON order_custom_fields
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = order_id
    AND o.organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid())
  ));

CREATE POLICY "owner_manage_order_workers"
  ON order_workers
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = order_id
    AND o.organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid())
  ));

CREATE POLICY "owner_manage_services"
  ON services
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (organization_id IN (SELECT id FROM organizations WHERE owner_id = auth.uid()));

-- Grant sequence permissions explicitly
DO $$
DECLARE
    seq_name text;
BEGIN
    FOR seq_name IN 
        SELECT sequence_name 
        FROM information_schema.sequences 
        WHERE sequence_schema = 'public'
    LOOP
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %I TO postgres, authenticated', seq_name);
    END LOOP;
END
$$;