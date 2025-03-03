-- Drop all existing policies for orders and related tables
DROP POLICY IF EXISTS "allow_manage_orders" ON orders;
DROP POLICY IF EXISTS "allow_manage_order_services" ON order_services;
DROP POLICY IF EXISTS "allow_manage_order_custom_fields" ON order_custom_fields;
DROP POLICY IF EXISTS "allow_manage_order_workers" ON order_workers;
DROP POLICY IF EXISTS "allow_manage_services" ON services;

-- Create completely permissive policies
CREATE POLICY "allow_all_orders"
  ON orders
  FOR ALL 
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "allow_all_order_services"
  ON order_services
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "allow_all_order_custom_fields"
  ON order_custom_fields
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "allow_all_order_workers"
  ON order_workers
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "allow_all_services"
  ON services
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Ensure RLS is enabled but completely permissive
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_custom_fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;

-- Grant full access to authenticated users
GRANT ALL ON orders TO authenticated;
GRANT ALL ON order_services TO authenticated;
GRANT ALL ON order_custom_fields TO authenticated;
GRANT ALL ON order_workers TO authenticated;
GRANT ALL ON services TO authenticated;

-- Grant sequence access
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;