-- ============================================================
-- Kloud Kart: Inventory reconciliation review
--
-- Compares current product stock with net inventory movements.
--
-- IMPORTANT:
-- This is an exception-detection aid, not proof of incorrect
-- stock. Opening balances are not supplied in the dataset.
-- ============================================================

CREATE OR REPLACE VIEW inventory_reconciliation_review AS

WITH logged_movements AS (

    SELECT
        product_id,
        SUM(change_qty) AS net_logged_change,
        COUNT(*) AS movement_count
    FROM inventory_log
    GROUP BY product_id
)

SELECT
    p.product_id,
    p.product_name,
    p.stock_quantity AS current_stock,

    COALESCE(lm.net_logged_change, 0)
        AS net_logged_change,

    p.stock_quantity - COALESCE(lm.net_logged_change, 0)
        AS implied_opening_stock,

    COALESCE(lm.movement_count, 0)
        AS movement_count,

    CASE
        WHEN p.stock_quantity = COALESCE(lm.net_logged_change, 0)
            THEN 'MATCHES_ZERO_OPENING_BALANCE'

        ELSE 'REVIEW_OPENING_BALANCE_OR_MISSING_MOVEMENTS'
    END AS reconciliation_status

FROM products p

LEFT JOIN logged_movements lm
    ON lm.product_id = p.product_id;
