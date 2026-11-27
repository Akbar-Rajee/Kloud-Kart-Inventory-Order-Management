-- ============================================================
-- Kloud Kart: Low-stock report across category hierarchy
--
-- Project default low-stock threshold: 5 units.
-- Change low_stock_settings.low_stock_threshold when policy changes.
-- Products are reported against their own category and
-- every reachable ancestor category.
-- ============================================================

CREATE OR REPLACE VIEW low_stock_category_report AS

WITH RECURSIVE low_stock_settings AS (
    SELECT 5::INTEGER AS low_stock_threshold
),

category_tree AS (

    -- Start with root categories
    SELECT
        category_id,
        category_name,
        parent_id,
        ARRAY[category_id] AS path
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    -- Recursively find child categories
    SELECT
        c.category_id,
        c.category_name,
        c.parent_id,
        ct.path || c.category_id
    FROM categories c
    JOIN category_tree ct
        ON c.parent_id = ct.category_id
    WHERE NOT c.category_id = ANY(ct.path)
),

low_stock_products AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category_id,
        p.stock_quantity
    FROM products AS p
    CROSS JOIN low_stock_settings AS settings
    WHERE p.stock_quantity <= settings.low_stock_threshold
      AND p.category_id IS NOT NULL
)

SELECT
    ancestor.category_id,
    ancestor.category_name,
    COUNT(DISTINCT lsp.product_id) AS low_stock_product_count,
    SUM(lsp.stock_quantity) AS total_stock_remaining

FROM low_stock_products lsp

JOIN category_tree leaf
    ON leaf.category_id = lsp.category_id

JOIN category_tree ancestor
    ON ancestor.category_id = ANY(leaf.path)

GROUP BY
    ancestor.category_id,
    ancestor.category_name;
