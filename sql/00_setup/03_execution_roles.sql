-- ============================================================
-- Kloud Kart: Least-privilege routine execution roles
-- Run as the database administrator before installing routines.
-- These roles cannot log in and receive no privileges here.
-- Remove public-schema CREATE before any SECURITY DEFINER routines are installed.
-- Table privileges are granted explicitly in the final security step.
-- ============================================================

BEGIN;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;

DO $$
BEGIN
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

ALTER ROLE kloudkart_order_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE kloudkart_inventory_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE kloudkart_dq_executor NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

COMMIT;
