/*
  # Add Clients Management

  1. New Tables
    - `clients`
      - `id` (uuid, primary key)
      - `organization_id` (uuid, references organizations)
      - `name` (text)
      - `phone` (text)
      - `address` (text)
      - `date_of_birth` (date)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

    - `client_custom_fields`
      - `id` (uuid, primary key)
      - `client_id` (uuid, references clients)
      - `title` (text)
      - `value` (text)
      - `type` (text) - can be 'text', 'file', or 'image'
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS on both tables
    - Add policies for organization owners to manage their clients
*/

-- Create clients table
CREATE TABLE clients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid REFERENCES organizations ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  phone text,
  address text,
  date_of_birth date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create client_custom_fields table
CREATE TABLE client_custom_fields (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid REFERENCES clients ON DELETE CASCADE NOT NULL,
  title text NOT NULL,
  value text NOT NULL,
  type text NOT NULL CHECK (type IN ('text', 'file', 'image')),
  created_at timestamptz DEFAULT now()
);

-- Create indexes
CREATE INDEX idx_clients_organization ON clients(organization_id);
CREATE INDEX idx_client_custom_fields_client ON client_custom_fields(client_id);

-- Enable RLS
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE client_custom_fields ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for clients
CREATE POLICY "organizations_owner_select_clients"
  ON clients FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = clients.organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_insert_clients"
  ON clients FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = organization_id
      AND owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_update_clients"
  ON clients FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = clients.organization_id
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

CREATE POLICY "organizations_owner_delete_clients"
  ON clients FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations
      WHERE id = clients.organization_id
      AND owner_id = auth.uid()
    )
  );

-- Create RLS policies for client_custom_fields
CREATE POLICY "organizations_owner_select_client_fields"
  ON client_custom_fields FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN clients c ON c.organization_id = o.id
      WHERE c.id = client_custom_fields.client_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_insert_client_fields"
  ON client_custom_fields FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN clients c ON c.organization_id = o.id
      WHERE c.id = client_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_update_client_fields"
  ON client_custom_fields FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN clients c ON c.organization_id = o.id
      WHERE c.id = client_custom_fields.client_id
      AND o.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN clients c ON c.organization_id = o.id
      WHERE c.id = client_id
      AND o.owner_id = auth.uid()
    )
  );

CREATE POLICY "organizations_owner_delete_client_fields"
  ON client_custom_fields FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM organizations o
      JOIN clients c ON c.organization_id = o.id
      WHERE c.id = client_custom_fields.client_id
      AND o.owner_id = auth.uid()
    )
  );