/*
  # Add Services and Orders

  1. New Tables
    - `services`: Store organization services
      - `id` (uuid, primary key)
      - `organization_id` (uuid, references organizations)
      - `name` (text)
      - `cost` (numeric)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `orders`: Store client orders
      - `id` (uuid, primary key)
      - `organization_id` (uuid, references organizations)
      - `client_id` (uuid, references clients)
      - `worker_id` (uuid, references workers)
      - `description` (text)
      - `due_date` (date)
      - `status` (text)
      - `total_amount` (numeric)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `order_services`: Link orders to services
      - `id` (uuid, primary key)
      - `order_id` (uuid, references orders)
      - `service_id` (uuid, references services)
      - `quantity` (integer)
      - `cost` (numeric)
      - `created_at` (timestamptz)

    - `order_custom_fields`: Store selected client custom fields
      - `id` (uuid, primary key)
      - `order_id` (uuid, references orders)
      - `field_id` (uuid, references client_custom_fields)
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on all tables
    - Add policies for organization owners
*/

-- Create services table
CREATE TABLE services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  cost numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create orders table
CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations ON DELETE CASCADE NOT NULL,
  client_id uuid REFERENCES clients ON DELETE CASCADE NOT NULL,
  worker_id uuid REFERENCES workers ON DELETE SET NULL,
  description text,
  due_date date,
  status text NOT NULL CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')) DEFAULT 'pending',
  total_amount numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create order_services table
CREATE TABLE order_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders ON DELETE CASCADE NOT NULL,
  service_id uuid REFERENCES services ON DELETE RESTRICT NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  cost numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create order_custom_fields table
CREATE TABLE order_custom_fields (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders ON DELETE CASCADE NOT NULL,
  field_id uuid REFERENCES client_custom_fields ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(order_id, field_id)
);

-- Create indexes
CREATE INDEX idx_services_organization ON services(organization_id);
CREATE INDEX idx_orders_organization ON orders(organization_id);
CREATE INDEX idx_orders_client ON orders(client_id);
CREATE INDEX idx_orders_worker ON orders(worker_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_order_services_order ON order_services(order_id);
CREATE INDEX idx_order_services_service ON order_services(service_id);
CREATE INDEX idx_order_custom_fields_order ON order_custom_fields(order_id);
CREATE INDEX idx_order_custom_fields_field ON order_custom_fields(field_id);

-- Enable RLS
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_custom_fields ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for services
CREATE POLICY "organizations_owner_manage_services"
  ON services
  TO authenticated
  USING (
    organization_id IN (
      SELECT id FROM organizations WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    organization_id IN (
      SELECT id FROM organizations WHERE owner_id = auth.uid()
    )
  );

-- Create RLS policies for orders
CREATE POLICY "organizations_owner_manage_orders"
  ON orders
  TO authenticated
  USING (
    organization_id IN (
      SELECT id FROM organizations WHERE owner_id = auth.uid()
    )
  )
  WITH CHECK (
    organization_id IN (
      SELECT id FROM organizations WHERE owner_id = auth.uid()
    )
  );

-- Create RLS policies for order_services
CREATE POLICY "organizations_owner_manage_order_services"
  ON order_services
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_services.order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  );

-- Create RLS policies for order_custom_fields
CREATE POLICY "organizations_owner_manage_order_custom_fields"
  ON order_custom_fields
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_custom_fields.order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM orders o
      WHERE o.id = order_id
      AND o.organization_id IN (
        SELECT id FROM organizations WHERE owner_id = auth.uid()
      )
    )
  );