/*
  # Fix Database Permissions
  
  1. Changes
    - Grant schema and table permissions to all necessary roles
    - Enable RLS on all relevant tables
    - Create permissive policies with unique names
    - Grant sequence permissions
*/

-- First, ensure schema permissions are correct
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;

-- Grant table permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, authenticated;

-- Ensure RLS is enabled but with permissive policies
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_custom_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to avoid conflicts
DROP POLICY IF EXISTS "temp_allow_orders" ON orders;
DROP POLICY IF EXISTS "temp_allow_order_services" ON order_services;
DROP POLICY IF EXISTS "temp_allow_order_custom_fields" ON order_custom_fields;
DROP POLICY IF EXISTS "temp_allow_order_workers" ON order_workers;
DROP POLICY IF EXISTS "temp_allow_services" ON services;

-- Create completely permissive policies for testing
CREATE POLICY "temp_allow_orders"
  ON orders FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "temp_allow_order_services"
  ON order_services FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "temp_allow_order_custom_fields"
  ON order_custom_fields FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "temp_allow_order_workers"
  ON order_workers FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "temp_allow_services"
  ON services FOR ALL
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
        -- Grant full permissions on sequences
        EXECUTE format('GRANT ALL ON SEQUENCE %I TO authenticated', seq_name);
        EXECUTE format('GRANT ALL ON SEQUENCE %I TO postgres', seq_name);
    END LOOP;
END
$$;