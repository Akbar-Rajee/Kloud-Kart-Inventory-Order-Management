-- ============================================================
-- Kloud Kart: Stock protection
-- Existing negative historical balances are preserved. The NOT VALID
-- constraint is enforced for new or updated rows without validating
-- every historical row during installation.
-- Safe to run repeatedly.
-- ============================================================

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.products'::regclass
          AND conname = 'products_stock_nonnegative'
    ) THEN
        ALTER TABLE public.products
            ADD CONSTRAINT products_stock_nonnegative
            CHECK (stock_quantity >= 0) NOT VALID;
    END IF;
END;
$$;

COMMIT;
