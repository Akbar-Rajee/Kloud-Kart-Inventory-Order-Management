-- ============================================================
-- Kloud Kart: Safe order placement
--
-- Prevents overselling through an atomic conditional UPDATE.
-- Order, order item, and inventory movement are recorded
-- within the same transaction.
-- ============================================================

CREATE OR REPLACE FUNCTION place_order(
    p_customer_id BIGINT,
    p_product_id BIGINT,
    p_quantity INTEGER
)
RETURNS TABLE (
    success BOOLEAN,
    order_id BIGINT,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
    v_order_id BIGINT;
    v_price NUMERIC(12,2);
BEGIN
    -- Validate quantity
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RETURN QUERY
        SELECT FALSE, NULL::BIGINT,
               'Quantity must be greater than zero';
        RETURN;
    END IF;

    -- Validate customer
    IF NOT EXISTS (
        SELECT 1
        FROM public.customers c
        WHERE c.customer_id = p_customer_id
    ) THEN
        RETURN QUERY
        SELECT FALSE, NULL::BIGINT, 'Customer not found';
        RETURN;
    END IF;

    -- Validate product
    IF NOT EXISTS (
        SELECT 1
        FROM public.products p
        WHERE p.product_id = p_product_id
    ) THEN
        RETURN QUERY
        SELECT FALSE, NULL::BIGINT, 'Product not found';
        RETURN;
    END IF;

    -- Atomically reserve stock.
    -- Concurrent transactions must re-check this condition
    -- after waiting for the product row lock.
    UPDATE public.products
    SET stock_quantity = stock_quantity - p_quantity
    WHERE product_id = p_product_id
      AND stock_quantity >= p_quantity
      AND stock_quantity IS NOT NULL
      AND price IS NOT NULL
    RETURNING price INTO v_price;

    -- Explain why stock was not reserved.
    IF NOT FOUND THEN
        IF EXISTS (
            SELECT 1
            FROM public.products p
            WHERE p.product_id = p_product_id
              AND p.stock_quantity >= p_quantity
              AND p.price IS NULL
        ) THEN
            RETURN QUERY
            SELECT FALSE, NULL::BIGINT,
                   'Product price is unavailable';
        ELSE
            RETURN QUERY
            SELECT FALSE, NULL::BIGINT, 'Out of stock';
        END IF;

        RETURN;
    END IF;

    -- Create the order
    INSERT INTO public.orders (
        customer_id,
        order_date,
        status,
        total_amount
    )
    VALUES (
        p_customer_id,
        CURRENT_TIMESTAMP,
        'Pending',
        v_price * p_quantity
    )
    RETURNING order_id INTO v_order_id;

    -- Create the order item
    INSERT INTO public.order_items (
        order_id,
        product_id,
        quantity,
        unit_price
    )
    VALUES (
        v_order_id,
        p_product_id,
        p_quantity,
        v_price
    );

    -- Record the inventory movement
    INSERT INTO public.inventory_log (
        product_id,
        change_qty,
        reason,
        created_at,
        note
    )
    VALUES (
        p_product_id,
        -p_quantity,
        'sale',
        CURRENT_TIMESTAMP,
        'Order ID: ' || v_order_id
    );

    RETURN QUERY
    SELECT TRUE, v_order_id, 'Order placed successfully';

    RETURN;
END;
$$;

REVOKE ALL ON FUNCTION public.place_order(bigint, bigint, integer) FROM PUBLIC;
