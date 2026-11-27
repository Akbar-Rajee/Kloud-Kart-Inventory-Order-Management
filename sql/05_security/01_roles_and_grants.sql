-- ============================================================
-- Kloud Kart: Application roles and least-privilege permissions
-- Run AFTER all tables, views and routines have been installed.
-- Run as the database owner / administrator.
-- ============================================================

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kloudkart_reader') THEN
        CREATE ROLE kloudkart_reader NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kloudkart_order_user') THEN
        CREATE ROLE kloudkart_order_user NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kloudkart_inventory_user') THEN
        CREATE ROLE kloudkart_inventory_user NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kloudkart_admin') THEN
        CREATE ROLE kloudkart_admin NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kloudkart_order_executor') THEN
        CREATE ROLE kloudkart_order_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kloudkart_inventory_executor') THEN
        CREATE ROLE kloudkart_inventory_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'kloudkart_dq_executor') THEN
        CREATE ROLE kloudkart_dq_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    END IF;
END;
$$;

ALTER ROLE kloudkart_reader NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE kloudkart_order_user NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE kloudkart_inventory_user NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE kloudkart_admin NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE kloudkart_order_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE kloudkart_inventory_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE kloudkart_dq_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

-- Prevent untrusted roles from adding shadow objects to public.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM
    kloudkart_reader, kloudkart_order_user, kloudkart_inventory_user,
    kloudkart_admin, kloudkart_order_executor,
    kloudkart_inventory_executor, kloudkart_dq_executor;
GRANT USAGE ON SCHEMA public TO
    kloudkart_reader, kloudkart_order_user, kloudkart_inventory_user,
    kloudkart_admin, kloudkart_order_executor,
    kloudkart_inventory_executor, kloudkart_dq_executor;

-- Minimal customer lookup: no email or telephone data exposed to order users.
CREATE OR REPLACE VIEW public.order_customer_lookup AS
SELECT customer_id, full_name, city
FROM public.customers;

-- Reporting role: read-only access to curated reports.
GRANT SELECT ON public.customer_spending_report,
    public.low_stock_category_report,
    public.inventory_reconciliation_review,
    public.product_category_exceptions
TO kloudkart_reader;

-- Order user sees the minimum lookup view and can invoke order placement.
GRANT SELECT ON public.order_customer_lookup TO kloudkart_order_user;

-- Inventory user can inspect stock and movements, but writes through routine.
GRANT SELECT ON public.products, public.categories, public.inventory_log,
    public.low_stock_category_report, public.inventory_reconciliation_review,
    public.product_category_exceptions
TO kloudkart_inventory_user;

-- Admin can inspect data and maintain only exception workflow fields.
GRANT SELECT ON public.products, public.categories, public.inventory_log,
    public.data_quality_exceptions, public.customer_spending_report,
    public.low_stock_category_report, public.inventory_reconciliation_review,
    public.product_category_exceptions
TO kloudkart_admin;
GRANT UPDATE (status, resolved_at, resolution_note)
ON public.data_quality_exceptions TO kloudkart_admin;

-- Narrow permissions for SECURITY DEFINER routine owners.
GRANT SELECT ON public.customers, public.products TO kloudkart_order_executor;
GRANT SELECT (order_id) ON public.orders TO kloudkart_order_executor;
GRANT UPDATE (stock_quantity) ON public.products TO kloudkart_order_executor;
GRANT INSERT ON public.orders, public.order_items, public.inventory_log
TO kloudkart_order_executor;
GRANT USAGE, SELECT ON SEQUENCE public.orders_order_id_seq,
    public.order_items_order_item_id_seq, public.inventory_log_log_id_seq
TO kloudkart_order_executor;

GRANT SELECT ON public.products TO kloudkart_inventory_executor;
GRANT UPDATE (stock_quantity) ON public.products TO kloudkart_inventory_executor;
GRANT INSERT ON public.inventory_log TO kloudkart_inventory_executor;
GRANT USAGE, SELECT ON SEQUENCE public.inventory_log_log_id_seq
TO kloudkart_inventory_executor;

GRANT SELECT ON public.categories, public.customers, public.products,
    public.orders, public.order_items, public.inventory_log
TO kloudkart_dq_executor;
GRANT SELECT, INSERT, UPDATE ON public.data_quality_exceptions
TO kloudkart_dq_executor;
GRANT USAGE, SELECT ON SEQUENCE public.data_quality_exceptions_exception_id_seq
TO kloudkart_dq_executor;

-- PostgreSQL requires CREATE on the containing schema when changing
-- routine ownership. Grant it only for this transaction, then revoke it.
GRANT CREATE ON SCHEMA public TO
    kloudkart_order_executor, kloudkart_inventory_executor, kloudkart_dq_executor;

-- Assign the routines to restricted, non-login owners.
ALTER FUNCTION public.place_order(bigint, bigint, integer)
    OWNER TO kloudkart_order_executor;
ALTER FUNCTION public.adjust_inventory(bigint, integer, text, text)
    OWNER TO kloudkart_inventory_executor;
ALTER PROCEDURE public.scan_data_quality_exceptions()
    OWNER TO kloudkart_dq_executor;

REVOKE CREATE ON SCHEMA public FROM
    kloudkart_order_executor, kloudkart_inventory_executor, kloudkart_dq_executor;

-- Application roles may execute only their intended routines.
REVOKE ALL ON FUNCTION public.place_order(bigint, bigint, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.place_order(bigint, bigint, integer)
TO kloudkart_order_user;

REVOKE ALL ON FUNCTION public.adjust_inventory(bigint, integer, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.adjust_inventory(bigint, integer, text, text)
TO kloudkart_inventory_user;

REVOKE ALL ON PROCEDURE public.scan_data_quality_exceptions() FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE public.scan_data_quality_exceptions()
TO kloudkart_admin;

-- The standalone helper is not part of the application API.
REVOKE ALL ON FUNCTION public.record_data_quality_exception(text, text, text, jsonb)
FROM PUBLIC;

COMMIT;
