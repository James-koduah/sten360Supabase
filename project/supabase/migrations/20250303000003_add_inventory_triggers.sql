-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS update_stock_quantity();
DROP FUNCTION IF EXISTS update_sales_order_payment_status();

-- Create payment status update function
CREATE OR REPLACE FUNCTION update_sales_order_payment_status()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_paid DECIMAL(10,2);
BEGIN
    -- Get total payments directly without CTE
    SELECT COALESCE(SUM(amount), 0)
    INTO v_total_paid
    FROM payments
    WHERE sales_order_id = NEW.sales_order_id;

    -- Update sales order
    UPDATE sales_orders
    SET 
        outstanding_balance = total_amount - v_total_paid,
        payment_status = 
            CASE 
                WHEN v_total_paid >= total_amount THEN 'paid'::payment_status
                WHEN v_total_paid > 0 THEN 'partially_paid'::payment_status
                ELSE 'unpaid'::payment_status
            END,
        updated_at = NOW()
    WHERE id = NEW.sales_order_id;
    
    RETURN NEW;
END;
$$;

-- Create stock update function
CREATE OR REPLACE FUNCTION update_stock_quantity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only update stock for non-custom items
    IF NOT NEW.is_custom_item AND NEW.product_id IS NOT NULL THEN
        -- Check if there's enough stock
        IF NOT EXISTS (
            SELECT 1 FROM products 
            WHERE id = NEW.product_id 
            AND stock_quantity >= NEW.quantity
        ) THEN
            RAISE EXCEPTION 'Insufficient stock for product %', NEW.product_id;
        END IF;
        
        -- Update stock quantity
        UPDATE products
        SET 
            stock_quantity = stock_quantity - NEW.quantity,
            updated_at = NOW()
        WHERE id = NEW.product_id;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create triggers if tables exist
DO $$ 
BEGIN
    -- Check if required tables exist
    IF EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_name IN ('sales_orders', 'payments', 'sales_order_items', 'products')
        AND table_schema = current_schema()
        GROUP BY table_schema 
        HAVING COUNT(*) = 4
    ) THEN
        -- Drop existing triggers if they exist
        DROP TRIGGER IF EXISTS update_stock ON sales_order_items;
        DROP TRIGGER IF EXISTS update_payment_status ON payments;

        -- Create triggers
        CREATE TRIGGER update_payment_status
        AFTER INSERT OR UPDATE OR DELETE ON payments
        FOR EACH ROW EXECUTE FUNCTION update_sales_order_payment_status();

        CREATE TRIGGER update_stock
        AFTER INSERT ON sales_order_items
        FOR EACH ROW EXECUTE FUNCTION update_stock_quantity();
    ELSE
        RAISE NOTICE 'Required tables do not exist yet. Triggers will not be created.';
    END IF;
END $$;