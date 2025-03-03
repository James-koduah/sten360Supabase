-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.create_order(
    p_organization_id uuid,
    p_client_id uuid,
    p_description text,
    p_due_date date,
    p_total_amount numeric,
    p_workers jsonb[],
    p_services jsonb[],
    p_custom_fields uuid[]
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.record_payment(
    p_organization_id uuid,
    p_order_id uuid,
    p_amount numeric,
    p_payment_method text,
    p_payment_reference text,
    p_recorded_by uuid
) TO authenticated;

-- Verify table permissions
GRANT ALL ON orders TO authenticated;
GRANT ALL ON order_services TO authenticated;
GRANT ALL ON order_workers TO authenticated;
GRANT ALL ON order_custom_fields TO authenticated;
GRANT ALL ON payments TO authenticated;

-- Verify sequence permissions (for order number generation)
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Add RLS policies if they don't exist
DO $$ 
BEGIN
    -- Orders policy
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_policies 
        WHERE tablename = 'orders' AND policyname = 'orders_org_isolation'
    ) THEN
        CREATE POLICY orders_org_isolation ON orders
            USING (organization_id IN (
                SELECT id FROM organizations 
                WHERE owner_id = auth.uid()
            ));
    END IF;

    -- Order services policy
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_policies 
        WHERE tablename = 'order_services' AND policyname = 'order_services_org_isolation'
    ) THEN
        CREATE POLICY order_services_org_isolation ON order_services
            USING (order_id IN (
                SELECT o.id FROM orders o
                JOIN organizations org ON org.id = o.organization_id
                WHERE org.owner_id = auth.uid()
            ));
    END IF;

    -- Order workers policy
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_policies 
        WHERE tablename = 'order_workers' AND policyname = 'order_workers_org_isolation'
    ) THEN
        CREATE POLICY order_workers_org_isolation ON order_workers
            USING (order_id IN (
                SELECT o.id FROM orders o
                JOIN organizations org ON org.id = o.organization_id
                WHERE org.owner_id = auth.uid()
            ));
    END IF;

    -- Order custom fields policy
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_policies 
        WHERE tablename = 'order_custom_fields' AND policyname = 'order_custom_fields_org_isolation'
    ) THEN
        CREATE POLICY order_custom_fields_org_isolation ON order_custom_fields
            USING (order_id IN (
                SELECT o.id FROM orders o
                JOIN organizations org ON org.id = o.organization_id
                WHERE org.owner_id = auth.uid()
            ));
    END IF;

    -- Payments policy
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_policies 
        WHERE tablename = 'payments' AND policyname = 'payments_org_isolation'
    ) THEN
        CREATE POLICY payments_org_isolation ON payments
            USING (organization_id IN (
                SELECT id FROM organizations 
                WHERE owner_id = auth.uid()
            ));
    END IF;
END $$; 