-- Create sequence for order IDs
CREATE SEQUENCE order_number_seq;

-- Add order_number column to orders table
ALTER TABLE orders
ADD COLUMN order_number text UNIQUE;

-- Create function to generate order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS trigger AS $$
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
$$ LANGUAGE plpgsql;

-- Create trigger to automatically generate order number
CREATE TRIGGER set_order_number
  BEFORE INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION generate_order_number();