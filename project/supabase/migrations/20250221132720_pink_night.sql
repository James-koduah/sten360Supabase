-- Grant schema usage to all necessary roles
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;

-- Grant table permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, authenticated;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "owner_manage_orders" ON orders;
DROP POLICY IF EXISTS "owner_manage_order_services" ON order_services;
DROP POLICY IF EXISTS "owner_manage_order_custom_fields" ON order_custom_fields;
DROP POLICY IF EXISTS "owner_manage_order_workers" ON order_workers;
DROP POLICY IF EXISTS "owner_manage_services" ON services;

-- Create new permissive policies
CREATE POLICY "allow_manage_orders"
  ON orders
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "allow_manage_order_services"
  ON order_services
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "allow_manage_order_custom_fields"
  ON order_custom_fields
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "allow_manage_order_workers"
  ON order_workers
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "allow_manage_services"
  ON services
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Ensure all sequences are accessible
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