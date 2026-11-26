-- ============================================================
-- Kloud Kart: Product category exceptions
--
-- Identifies:
-- 1. Products with no category assigned.
-- 2. Products referencing a category that does not exist.
-- 3. Products assigned to categories outside the
--    root-connected category hierarchy.
--
-- Does not delete or automatically reassign dirty records.
-- ============================================================

CREATE OR REPLACE VIEW product_category_exceptions AS

WITH RECURSIVE category_tree AS (

    SELECT
        category_id,
        parent_id,
        ARRAY[category_id] AS path
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT
        c.category_id,
        c.parent_id,
        ct.path || c.category_id
    FROM categories c
    JOIN category_tree ct
        ON c.parent_id = ct.category_id
    WHERE NOT c.category_id = ANY(ct.path)
)

SELECT
    p.product_id,
    p.product_name,
    p.category_id,
    c.category_name,
    p.stock_quantity,

    CASE
        WHEN p.category_id IS NULL
            THEN 'MISSING_CATEGORY'

        WHEN c.category_id IS NULL
            THEN 'CATEGORY_DOES_NOT_EXIST'

        ELSE 'CATEGORY_NOT_REACHABLE'
    END AS exception_type

FROM products p

LEFT JOIN categories c
    ON c.category_id = p.category_id

WHERE
    p.category_id IS NULL

    OR NOT EXISTS (
        SELECT 1
        FROM category_tree ct
        WHERE ct.category_id = p.category_id
    );
