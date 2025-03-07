-- Update the record_payment function to work with the new payments table structure
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
BEGIN
  -- Validate payment method
  IF p_payment_method NOT IN ('mobile_money', 'bank_transfer', 'cash', 'other') THEN
    RAISE EXCEPTION 'Invalid payment method';
  END IF;

  -- Insert payment record
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

  RETURN v_payment;
END;
$$;

-- Grant permissions for the updated function
GRANT EXECUTE ON FUNCTION record_payment(uuid, uuid, numeric, text, text, uuid) TO authenticated; 