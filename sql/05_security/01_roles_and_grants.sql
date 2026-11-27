-- ============================================================
-- Kloud Kart: Application roles and least-privilege permissions
-- Run AFTER all project tables, views and routines are created.
-- Run as the database owner / administrator.
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kloudkart_reader') THEN
        EXECUTE 'CREATE ROLE kloudkart_reader NOLOGIN';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kloudkart_order_user') THEN
        EXECUTE 'CREATE ROLE kloudkart_order_user NOLOGIN';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kloudkart_inventory_user') THEN
        EXECUTE 'CREATE ROLE kloudkart_inventory_user NOLOGIN';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kloudkart_admin') THEN
        EXECUTE 'CREATE ROLE kloudkart_admin NOLOGIN';
    END IF;
END
$$;

-- Schema access
GRANT USAGE ON SCHEMA public TO
    kloudkart_reader,
    kloudkart_order_user,
    kloudkart_inventory_user,
    kloudkart_admin;

-- Read-only reporting access
GRANT SELECT ON
    products,
    categories,
    customer_spending_report,
    low_stock_category_report,
    inventory_reconciliation_review,
    product_category_exceptions
TO kloudkart_reader;

-- Order-processing access
GRANT SELECT ON products, categories, order_customer_lookup
TO kloudkart_order_user;

-- Inventory-management access
GRANT SELECT ON
    products,
    categories,
    inventory_log,
    low_stock_category_report,
    inventory_reconciliation_review,
    product_category_exceptions
TO kloudkart_inventory_user;

-- Administrative and data-quality access
GRANT SELECT ON
    products,
    categories,
    inventory_log,
    data_quality_exceptions,
    customer_spending_report,
    low_stock_category_report,
    inventory_reconciliation_review,
    product_category_exceptions
TO kloudkart_admin;

-- Restrict privileged routine execution to the intended roles
REVOKE ALL ON FUNCTION public.place_order(bigint, bigint, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.place_order(bigint, bigint, integer)
TO kloudkart_order_user;

REVOKE ALL ON FUNCTION public.adjust_inventory(bigint, integer, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.adjust_inventory(bigint, integer, text, text)
TO kloudkart_inventory_user;

REVOKE ALL ON PROCEDURE public.scan_data_quality_exceptions() FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE public.scan_data_quality_exceptions()
TO kloudkart_admin;

-- The exception-recording helper is not directly exposed to application users.
DO $$
DECLARE
    routine_signature text;
BEGIN
    FOR routine_signature IN
        SELECT p.oid::regprocedure::text
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'record_data_quality_exception'
          AND p.prokind = 'f'
    LOOP
        EXECUTE format(
            'REVOKE ALL ON FUNCTION %s FROM PUBLIC',
            routine_signature
        );
    END LOOP;
END
$$;
