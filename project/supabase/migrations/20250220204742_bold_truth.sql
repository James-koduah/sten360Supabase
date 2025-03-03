-- Drop existing sequence and start fresh
DROP SEQUENCE IF EXISTS order_number_seq;

-- Create new sequence with a higher start value to avoid conflicts
CREATE SEQUENCE order_number_seq START WITH 10000;

-- Modify the generate_order_number function to be more robust
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
  org_prefix text;
  next_number int;
  final_number text;
  attempts int := 0;
  max_attempts int := 5;
BEGIN
  -- Get organization name prefix (first letter of each word)
  SELECT string_agg(left(word, 1), '')
  INTO org_prefix
  FROM (
    SELECT regexp_split_to_table(upper(name), '\s+') as word
    FROM organizations
    WHERE id = NEW.organization_id
  ) words;

  -- Loop until we find a unique number or max attempts reached
  LOOP
    -- Get next number from sequence
    SELECT nextval('order_number_seq') INTO next_number;
    
    -- Format order number: PREFIX-YYYYMM-XXXXX
    final_number := org_prefix || '-' || 
                   to_char(NEW.created_at, 'YYYYMM') || '-' ||
                   lpad(next_number::text, 5, '0');

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
$function$;

-- Drop existing trigger
DROP TRIGGER IF EXISTS set_order_number ON orders;

-- Create new trigger
CREATE TRIGGER set_order_number
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION generate_order_number();

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);

-- Make sure order_number is required
ALTER TABLE orders 
ALTER COLUMN order_number SET NOT NULL;