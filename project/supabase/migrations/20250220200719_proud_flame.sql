-- Create sequence for order IDs if it doesn't exist
CREATE SEQUENCE IF NOT EXISTS order_number_seq;

-- Add order_number column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'orders' AND column_name = 'order_number'
  ) THEN
    ALTER TABLE orders
    ADD COLUMN order_number text UNIQUE;
  END IF;
END $$;

-- Create function to generate order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
  org_prefix text;
  next_number int;
BEGIN
  -- Get organization name prefix (first letter of each word)
  SELECT string_agg(left(word, 1), '')
  INTO org_prefix
  FROM (
    SELECT regexp_split_to_table(upper(name), '\s+') as word
    FROM organizations
    WHERE id = NEW.organization_id
  ) words;

  -- Get next number from sequence
  SELECT nextval('order_number_seq') INTO next_number;

  -- Format order number: PREFIX-YYYYMM-XXXX
  NEW.order_number := org_prefix || '-' || 
                     to_char(NEW.created_at, 'YYYYMM') || '-' ||
                     lpad(next_number::text, 4, '0');
  
  RETURN NEW;
END;
$function$;

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS set_order_number ON orders;

-- Create trigger to automatically generate order number
CREATE TRIGGER set_order_number
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION generate_order_number();

-- Update existing orders with order numbers
WITH numbered_orders AS (
  SELECT 
    id,
    organization_id,
    created_at,
    ROW_NUMBER() OVER (ORDER BY created_at) as rn
  FROM orders
  WHERE order_number IS NULL
)
UPDATE orders o
SET order_number = (
  SELECT 
    (
      SELECT string_agg(left(word, 1), '')
      FROM (
        SELECT regexp_split_to_table(upper(name), '\s+') as word
        FROM organizations
        WHERE id = no.organization_id
      ) words
    ) || '-' ||
    to_char(no.created_at, 'YYYYMM') || '-' ||
    lpad(no.rn::text, 4, '0')
  FROM numbered_orders no
  WHERE no.id = o.id
)
WHERE o.order_number IS NULL;