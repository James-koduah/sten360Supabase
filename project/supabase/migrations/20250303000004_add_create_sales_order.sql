-- Create stored procedure for sales order creation
CREATE OR REPLACE FUNCTION create_sales_order(
  p_organization_id uuid,
  p_client_id uuid,
  p_total_amount numeric,
  p_services jsonb[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id uuid;
  v_order jsonb;
BEGIN
  -- Start transaction
  BEGIN
    -- Create sales order
    INSERT INTO sales_orders (
      organization_id,
      client_id,
      total_amount,
      outstanding_balance,
      payment_status
    )
    VALUES (
      p_organization_id,
      p_client_id,
      p_total_amount,
      p_total_amount,
      'unpaid'
    )
    RETURNING id INTO v_order_id;

    -- Add services/items
    INSERT INTO sales_order_items (
      sales_order_id,
      product_id,
      name,
      quantity,
      unit_price,
      total_price,
      is_custom_item
    )
    SELECT
      v_order_id,
      (item->>'product_id')::uuid,
      (item->>'name')::text,
      (item->>'quantity')::integer,
      (item->>'unit_price')::numeric,
      (item->>'total_price')::numeric,
      (item->>'is_custom_item')::boolean
    FROM unnest(p_services) AS item;

    -- Get the created order with all its details
    SELECT jsonb_build_object(
      'id', o.id,
      'order_number', o.order_number,
      'client_id', o.client_id,
      'total_amount', o.total_amount,
      'outstanding_balance', o.outstanding_balance,
      'payment_status', o.payment_status,
      'created_at', o.created_at
    ) INTO v_order
    FROM sales_orders o
    WHERE o.id = v_order_id;

    RETURN v_order;
  EXCEPTION
    WHEN OTHERS THEN
      -- Rollback will happen automatically
      RAISE EXCEPTION 'Failed to create sales order: %', SQLERRM;
  END;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION create_sales_order(uuid, uuid, numeric, jsonb[]) TO authenticated; 