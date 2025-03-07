-- Update the record_payment function to handle both orders and sales_orders tables
CREATE OR REPLACE FUNCTION record_payment(
  p_organization_id uuid,
  p_order_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_payment_reference text,
  p_recorded_by uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payment_id uuid;
  v_payment jsonb;
  v_is_sales_order boolean;
BEGIN
  -- Validate payment method
  IF p_payment_method NOT IN ('mobile_money', 'bank_transfer', 'cash', 'other') THEN
    RAISE EXCEPTION 'Invalid payment method';
  END IF;

  -- Check if this is a sales order or a regular order
  SELECT EXISTS (
    SELECT 1 FROM sales_orders WHERE id = p_order_id
  ) INTO v_is_sales_order;

  -- Insert payment record based on order type
  IF v_is_sales_order THEN
    -- This is a sales order
    INSERT INTO payments (
      sales_order_id,
      amount,
      payment_method,
      transaction_reference,
      recorded_by
    )
    VALUES (
      p_order_id,
      p_amount,
      p_payment_method::payment_method,
      p_payment_reference,
      p_recorded_by
    )
    RETURNING id INTO v_payment_id;

    -- Update outstanding balance in sales_orders
    UPDATE sales_orders
    SET 
      outstanding_balance = GREATEST(0, outstanding_balance - p_amount),
      payment_status = CASE 
        WHEN outstanding_balance - p_amount <= 0 THEN 'paid'
        ELSE 'partially_paid'
      END
    WHERE id = p_order_id;

    -- Get payment details
    SELECT jsonb_build_object(
      'id', p.id,
      'sales_order_id', p.sales_order_id,
      'amount', p.amount,
      'payment_method', p.payment_method,
      'transaction_reference', p.transaction_reference,
      'recorded_by', p.recorded_by,
      'created_at', p.created_at
    ) INTO v_payment
    FROM payments p
    WHERE p.id = v_payment_id;
  ELSE
    -- This is a regular order
    INSERT INTO payments (
      organization_id,
      order_id,
      amount,
      payment_method,
      payment_reference,
      recorded_by
    )
    VALUES (
      p_organization_id,
      p_order_id,
      p_amount,
      p_payment_method,
      p_payment_reference,
      p_recorded_by
    )
    RETURNING id INTO v_payment_id;

    -- Update outstanding balance in orders
    UPDATE orders
    SET 
      outstanding_balance = GREATEST(0, outstanding_balance - p_amount),
      payment_status = CASE 
        WHEN outstanding_balance - p_amount <= 0 THEN 'paid'
        ELSE 'partially_paid'
      END
    WHERE id = p_order_id;

    -- Get payment details
    SELECT jsonb_build_object(
      'id', p.id,
      'order_id', p.order_id,
      'amount', p.amount,
      'payment_method', p.payment_method,
      'payment_reference', p.payment_reference,
      'recorded_by', p.recorded_by,
      'created_at', p.created_at
    ) INTO v_payment
    FROM payments p
    WHERE p.id = v_payment_id;
  END IF;

  RETURN v_payment;
END;
$$;

-- Grant permissions for the updated function
GRANT EXECUTE ON FUNCTION record_payment(uuid, uuid, numeric, text, text, uuid) TO authenticated; 