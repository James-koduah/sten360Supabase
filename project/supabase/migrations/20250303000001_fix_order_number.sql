-- Drop existing trigger and function
DROP TRIGGER IF EXISTS set_order_number ON orders;
DROP FUNCTION IF EXISTS generate_order_number();

-- Create new function for generating order numbers with better uniqueness
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  org_prefix text;
  current_ym text;
  next_number int;
  sequence_name text;
  final_number text;
  attempts int := 0;
  max_attempts int := 5;
BEGIN
  -- Get organization name prefix
  SELECT string_agg(left(word, 1), '')
  INTO org_prefix
  FROM (
    SELECT regexp_split_to_table(upper(name), '\s+') as word
    FROM organizations
    WHERE id = NEW.organization_id
  ) words;

  -- Get current year and month
  current_ym := to_char(NEW.created_at, 'YYYYMM');
  
  -- Create sequence name with organization and date
  sequence_name := 'order_seq_' || NEW.organization_id || '_' || current_ym;
  
  -- Loop until we find a unique number or max attempts reached
  LOOP
    -- Create sequence if needed (separate for each org and month)
    EXECUTE format('
      CREATE SEQUENCE IF NOT EXISTS %I START WITH 1001 INCREMENT BY 1', sequence_name
    );
    
    -- Get next number from sequence
    EXECUTE format('SELECT nextval(%L)', sequence_name) INTO next_number;

    -- Format order number: PREFIX-YYYYMM-XXXX
    final_number := org_prefix || '-' || current_ym || '-' || lpad(next_number::text, 4, '0');

    -- Check if this number is already used
    IF NOT EXISTS (
      SELECT 1 FROM orders WHERE order_number = final_number
    ) THEN
      -- Found a unique number, use it
      NEW.order_number := final_number;
      RETURN NEW;
    END IF;

    attempts := attempts + 1;
    IF attempts >= max_attempts THEN
      RAISE EXCEPTION 'Could not generate unique order number after % attempts', max_attempts;
    END IF;
  END LOOP;
END;
$$;

-- Create new trigger
CREATE TRIGGER set_order_number
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION generate_order_number();

-- Create index for better performance if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);

-- Make sure order_number is required
ALTER TABLE orders 
ALTER COLUMN order_number SET NOT NULL; 