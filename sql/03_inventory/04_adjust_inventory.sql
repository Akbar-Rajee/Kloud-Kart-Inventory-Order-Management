-- ============================================================
-- Kloud Kart: Controlled inventory adjustments
--
-- Records restocks and stock corrections.
-- Stock update and movement logging are atomic.
-- ============================================================

CREATE OR REPLACE FUNCTION adjust_inventory(
    p_product_id BIGINT,
    p_change_qty INTEGER,
    p_reason TEXT,
    p_note TEXT
)
RETURNS TABLE (
    success BOOLEAN,
    resulting_stock INTEGER,
    message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_stock INTEGER;
    v_reason TEXT;
BEGIN
    -- Validate the quantity change.
    IF p_change_qty IS NULL OR p_change_qty = 0 THEN
        RETURN QUERY
        SELECT FALSE, NULL::INTEGER,
               'Quantity change must not be zero';
        RETURN;
    END IF;

    -- Normalize and validate the movement reason.
    v_reason := LOWER(TRIM(p_reason));

    IF v_reason IS NULL OR v_reason NOT IN ('restock', 'correction') THEN
        RETURN QUERY
        SELECT FALSE, NULL::INTEGER,
               'Reason must be restock or correction';
        RETURN;
    END IF;

    -- A restock must increase stock.
    IF v_reason = 'restock' AND p_change_qty <= 0 THEN
        RETURN QUERY
        SELECT FALSE, NULL::INTEGER,
               'Restock quantity must be positive';
        RETURN;
    END IF;

    -- Require an explanatory note.
    IF p_note IS NULL OR LENGTH(TRIM(p_note)) = 0 THEN
        RETURN QUERY
        SELECT FALSE, NULL::INTEGER,
               'An explanatory note is required';
        RETURN;
    END IF;

    -- Confirm that the product exists.
    IF NOT EXISTS (
        SELECT 1
        FROM products p
        WHERE p.product_id = p_product_id
    ) THEN
        RETURN QUERY
        SELECT FALSE, NULL::INTEGER,
               'Product not found';
        RETURN;
    END IF;

    -- Atomically update stock, preventing a negative balance.
    UPDATE products
    SET stock_quantity = stock_quantity + p_change_qty
    WHERE product_id = p_product_id
      AND stock_quantity IS NOT NULL
      AND stock_quantity + p_change_qty >= 0
    RETURNING stock_quantity INTO v_new_stock;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT FALSE, NULL::INTEGER,
               'Adjustment rejected: stock is unavailable or would become negative';
        RETURN;
    END IF;

    -- Record the corresponding inventory movement.
    INSERT INTO inventory_log (
        product_id,
        change_qty,
        reason,
        created_at,
        note
    )
    VALUES (
        p_product_id,
        p_change_qty,
        v_reason,
        CURRENT_TIMESTAMP,
        TRIM(p_note)
    );

    RETURN QUERY
    SELECT TRUE, v_new_stock,
           'Inventory adjustment recorded successfully';

    RETURN;
END;
$$;

