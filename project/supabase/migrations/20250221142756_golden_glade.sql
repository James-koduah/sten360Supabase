/*
  # Safe Removal of Orders System

  This migration safely removes all orders-related database objects by first checking their existence.
  This prevents errors when objects don't exist.

  1. Cleanup Steps
    - Drop dependent tables first (if they exist)
    - Drop main tables
    - Drop functions and triggers
    - Clean up sequences
*/

-- Drop dependent tables if they exist
DO $$ 
BEGIN
    -- Drop tables with foreign key dependencies first
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_items') THEN
        DROP TABLE order_items CASCADE;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_assignments') THEN
        DROP TABLE order_assignments CASCADE;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_workers') THEN
        DROP TABLE order_workers CASCADE;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_services') THEN
        DROP TABLE order_services CASCADE;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_custom_fields') THEN
        DROP TABLE order_custom_fields CASCADE;
    END IF;

    -- Drop main orders table if it exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'orders') THEN
        DROP TABLE orders CASCADE;
    END IF;
END $$;

-- Drop functions if they exist
DO $$ 
BEGIN
    -- Drop order-related functions
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'generate_order_number') THEN
        DROP FUNCTION generate_order_number CASCADE;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'cleanup_old_order_sequences') THEN
        DROP FUNCTION cleanup_old_order_sequences CASCADE;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_tasks_for_order_workers') THEN
        DROP FUNCTION create_tasks_for_order_workers CASCADE;
    END IF;
END $$;

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