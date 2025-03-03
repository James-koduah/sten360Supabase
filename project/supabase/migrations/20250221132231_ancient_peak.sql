-- Drop existing trigger and function
DROP TRIGGER IF EXISTS set_order_number ON orders;
DROP FUNCTION IF EXISTS generate_order_number();

-- Create new function for generating order numbers
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  org_prefix text;
  current_ym text;
  next_number int;
  sequence_name text;
BEGIN
  -- Get organization name prefix (first letter of each word)
  SELECT string_agg(left(word, 1), '')
  INTO org_prefix
  FROM (
    SELECT regexp_split_to_table(upper(name), '\s+') as word
    FROM organizations
    WHERE id = NEW.organization_id
  ) words;

  -- Get current year and month
  current_ym := to_char(NEW.created_at, 'YYYYMM');
  
  -- Create a unique sequence name for this organization and month
  sequence_name := 'order_seq_' || NEW.organization_id || '_' || current_ym;
  
  -- Create sequence if it doesn't exist
  EXECUTE format('
    CREATE SEQUENCE IF NOT EXISTS %I START WITH 10000', sequence_name
  );
  
  -- Get next number from sequence
  EXECUTE format('SELECT nextval(%L)', sequence_name) INTO next_number;

  -- Format order number: PREFIX-YYYYMM-XXXXX
  NEW.order_number := org_prefix || '-' || current_ym || '-' || lpad(next_number::text, 5, '0');
  
  RETURN NEW;
END;
$$;

-- Create new trigger
CREATE TRIGGER set_order_number
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION generate_order_number();

-- Create function to clean up old sequences
CREATE OR REPLACE FUNCTION cleanup_old_order_sequences()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  seq_name text;
BEGIN
  FOR seq_name IN 
    SELECT sequence_name 
    FROM information_schema.sequences 
    WHERE sequence_schema = 'public' 
    AND sequence_name LIKE 'order_seq_%'
    AND sequence_name NOT LIKE '%' || to_char(now(), 'YYYYMM')
  LOOP
    EXECUTE format('DROP SEQUENCE IF EXISTS %I', seq_name);
  END LOOP;
END;
$$;