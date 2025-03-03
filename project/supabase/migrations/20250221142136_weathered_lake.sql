/*
  # Remove Orders System

  This migration removes all orders-related database objects in a safe and controlled manner.

  1. Cleanup
    - Drop all orders-related tables
    - Drop associated functions and triggers
    - Drop sequences
    - Remove policies

  2. Order of Operations
    - Drop dependent tables first (child tables)
    - Drop main tables
    - Drop functions and triggers
    - Clean up sequences
*/

-- First drop dependent tables (respecting foreign key constraints)
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS order_assignments CASCADE;
DROP TABLE IF EXISTS order_workers CASCADE;
DROP TABLE IF EXISTS order_services CASCADE;
DROP TABLE IF EXISTS order_custom_fields CASCADE;

-- Drop main orders table
DROP TABLE IF EXISTS orders CASCADE;

-- Drop functions and triggers
DROP FUNCTION IF EXISTS generate_order_number() CASCADE;
DROP FUNCTION IF EXISTS cleanup_old_order_sequences() CASCADE;
DROP FUNCTION IF EXISTS create_tasks_for_order_workers() CASCADE;

-- Clean up any order-related sequences
DO $$
DECLARE
    seq_name text;
BEGIN
    FOR seq_name IN 
        SELECT sequence_name 
        FROM information_schema.sequences 
        WHERE sequence_schema = 'public'
        AND sequence_name LIKE 'order_seq_%'
    LOOP
        EXECUTE format('DROP SEQUENCE IF EXISTS %I CASCADE', seq_name);
    END LOOP;
END
$$;