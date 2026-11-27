-- ============================================================
-- Kloud Kart: Validate historical stock protection
-- Run only after all negative product balances are investigated
-- and corrected. The guard reports remaining product IDs.
-- ============================================================

DO $$
DECLARE
    remaining_ids TEXT;
BEGIN
    SELECT string_agg(product_id::TEXT, ', ' ORDER BY product_id)
    INTO remaining_ids
    FROM public.products
    WHERE stock_quantity < 0;

    IF remaining_ids IS NOT NULL THEN
        RAISE EXCEPTION
            'Cannot validate products_stock_nonnegative; negative stock remains for product IDs: %',
            remaining_ids;
    END IF;
END;
$$;

ALTER TABLE public.products
    VALIDATE CONSTRAINT products_stock_nonnegative;
