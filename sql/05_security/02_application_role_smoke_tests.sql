-- ============================================================
-- Kloud Kart: Application-role permission smoke tests
-- Run after 01_roles_and_grants.sql as database administrator.
-- These tests verify effective permissions without changing data.
-- ============================================================

DO $$
BEGIN
    IF NOT has_function_privilege('kloudkart_order_user',
        'public.place_order(bigint,bigint,integer)', 'EXECUTE') THEN
        RAISE EXCEPTION 'Order role cannot execute place_order';
    END IF;
    IF has_table_privilege('kloudkart_order_user', 'public.products', 'UPDATE') THEN
        RAISE EXCEPTION 'Order role unexpectedly has direct product UPDATE';
    END IF;
    IF has_table_privilege('kloudkart_order_user', 'public.orders', 'INSERT')
       OR has_table_privilege('kloudkart_order_user', 'public.order_items', 'INSERT')
       OR has_table_privilege('kloudkart_order_user', 'public.inventory_log', 'INSERT') THEN
        RAISE EXCEPTION 'Order role unexpectedly has direct INSERT privileges';
    END IF;
    IF NOT has_function_privilege('kloudkart_inventory_user',
        'public.adjust_inventory(bigint,integer,text,text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'Inventory role cannot execute adjust_inventory';
    END IF;
    IF has_table_privilege('kloudkart_inventory_user', 'public.products', 'UPDATE') THEN
        RAISE EXCEPTION 'Inventory role unexpectedly has direct product UPDATE';
    END IF;
    IF has_table_privilege('kloudkart_inventory_user', 'public.inventory_log', 'INSERT') THEN
        RAISE EXCEPTION 'Inventory role unexpectedly has direct inventory-log INSERT';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'scan_data_quality_exceptions'
          AND p.prokind = 'p'
          AND has_function_privilege('kloudkart_admin', p.oid, 'EXECUTE')
    ) THEN
        RAISE EXCEPTION 'Admin role cannot execute scanner';
    END IF;
    IF NOT has_column_privilege('kloudkart_admin',
        'public.data_quality_exceptions', 'status', 'UPDATE') THEN
        RAISE EXCEPTION 'Admin role cannot update exception status';
    END IF;
    IF has_table_privilege('kloudkart_admin',
        'public.data_quality_exceptions', 'DELETE') THEN
        RAISE EXCEPTION 'Admin role unexpectedly has DELETE on exception register';
    END IF;
END;
$$;

SELECT
    p.proname AS routine_name,
    pg_get_userbyid(p.proowner) AS routine_owner,
    p.prosecdef AS security_definer,
    p.proconfig AS routine_settings
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('place_order', 'adjust_inventory', 'scan_data_quality_exceptions')
ORDER BY p.proname;
