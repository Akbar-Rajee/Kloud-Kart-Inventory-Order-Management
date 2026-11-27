CREATE OR REPLACE PROCEDURE scan_data_quality_exceptions()
LANGUAGE plpgsql
AS $$
BEGIN
    WITH RECURSIVE reachable(category_id, path) AS (
            SELECT category_id, ARRAY[category_id]
            FROM categories
            WHERE parent_id IS NULL

            UNION ALL

            SELECT c.category_id, parent_path.path || c.category_id
            FROM categories c
            JOIN reachable parent_path ON c.parent_id = parent_path.category_id
            WHERE NOT c.category_id = ANY(parent_path.path)
        ),
        duplicate_emails AS (
            SELECT
                LOWER(BTRIM(email)) AS normalized_email,
                COUNT(*) AS group_size
            FROM customers
            WHERE email IS NOT NULL
              AND BTRIM(email) <> ''
            GROUP BY LOWER(BTRIM(email))
            HAVING COUNT(*) > 1
        ),
        order_item_totals AS (
            SELECT
                oi.order_id,
                COUNT(*)::INTEGER AS line_item_count,
                COUNT(oi.quantity)::INTEGER AS quantity_count,
                COUNT(oi.unit_price)::INTEGER AS unit_price_count,
                SUM(oi.quantity::NUMERIC * oi.unit_price) AS calculated_total
            FROM order_items oi
            GROUP BY oi.order_id
        ),
        exceptions AS (
            SELECT
                'products'::TEXT AS source_table,
                p.product_id::TEXT AS source_record_id,
                'NEGATIVE_STOCK'::TEXT AS issue_type,
                TO_JSONB(p) AS original_values
            FROM products p
            WHERE p.stock_quantity < 0

            UNION ALL

            SELECT
                'products', p.product_id::TEXT,
                'PRODUCT_CATEGORY_NULL',
                TO_JSONB(p)
            FROM products p
            WHERE p.category_id IS NULL

            UNION ALL

            SELECT
                'products', p.product_id::TEXT,
                'PRODUCT_CATEGORY_NOT_FOUND',
                TO_JSONB(p)
            FROM products p
            WHERE p.category_id IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM categories c
                  WHERE c.category_id = p.category_id
              )

            UNION ALL

            SELECT
                'orders', o.order_id::TEXT,
                'ORDER_CUSTOMER_MISSING',
                TO_JSONB(o)
            FROM orders o
            WHERE NOT EXISTS (
                SELECT 1 FROM customers c
                WHERE c.customer_id = o.customer_id
            )

            UNION ALL

            SELECT
                'order_items', oi.order_item_id::TEXT,
                'ORDER_ITEM_ORDER_MISSING',
                TO_JSONB(oi)
            FROM order_items oi
            WHERE NOT EXISTS (
                SELECT 1 FROM orders o
                WHERE o.order_id = oi.order_id
            )

            UNION ALL

            SELECT
                'order_items', oi.order_item_id::TEXT,
                'ORDER_ITEM_PRODUCT_MISSING',
                TO_JSONB(oi)
            FROM order_items oi
            WHERE oi.product_id IS NULL
               OR NOT EXISTS (
                   SELECT 1
                   FROM products p
                   WHERE p.product_id = oi.product_id
               )

            UNION ALL

            SELECT
                'order_items', oi.order_item_id::TEXT,
                'ORDER_ITEM_UNIT_PRICE_NULL',
                TO_JSONB(oi)
            FROM order_items oi
            WHERE oi.unit_price IS NULL

            UNION ALL

            SELECT
                'order_items', oi.order_item_id::TEXT,
                'ORDER_ITEM_ZERO_PRICE_REVIEW',
                TO_JSONB(oi)
            FROM order_items oi
            WHERE oi.unit_price = 0

            UNION ALL

            SELECT
                'order_items', oi.order_item_id::TEXT,
                'ORDER_ITEM_LARGE_QUANTITY_REVIEW',
                TO_JSONB(oi)
            FROM order_items oi
            WHERE oi.quantity >= 999

            UNION ALL

            SELECT
                'orders', o.order_id::TEXT,
                'ORDER_TOTAL_MISMATCH',
                TO_JSONB(o) || JSONB_BUILD_OBJECT(
                    'calculated_items_total', totals.calculated_total,
                    'total_difference', o.total_amount - totals.calculated_total,
                    'line_item_count', totals.line_item_count
                )
            FROM orders o
            JOIN order_item_totals totals
              ON totals.order_id = o.order_id
            WHERE totals.line_item_count > 0
              AND totals.quantity_count = totals.line_item_count
              AND totals.unit_price_count = totals.line_item_count
              AND o.total_amount IS NOT NULL
              AND o.total_amount <> totals.calculated_total

            UNION ALL

            SELECT
                'inventory_log', il.log_id::TEXT,
                'INVENTORY_PRODUCT_MISSING',
                TO_JSONB(il)
            FROM inventory_log il
            WHERE NOT EXISTS (
                SELECT 1 FROM products p
                WHERE p.product_id = il.product_id
            )

            UNION ALL

            SELECT
                'inventory_log', il.log_id::TEXT,
                'INVENTORY_NOTE_MISSING',
                TO_JSONB(il)
            FROM inventory_log il
            WHERE il.note IS NULL OR BTRIM(il.note) = ''

            UNION ALL

            SELECT
                'inventory_log', il.log_id::TEXT,
                'INVENTORY_ZERO_MOVEMENT_REVIEW',
                TO_JSONB(il)
            FROM inventory_log il
            WHERE il.change_qty = 0

            UNION ALL

            SELECT
                'categories', c.category_id::TEXT,
                'CATEGORY_PARENT_MISSING',
                TO_JSONB(c)
            FROM categories c
            WHERE c.parent_id IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM categories parent
                  WHERE parent.category_id = c.parent_id
              )

            UNION ALL

            SELECT
                'categories', c.category_id::TEXT,
                'CATEGORY_NOT_REACHABLE_FROM_ROOT',
                TO_JSONB(c)
            FROM categories c
            WHERE NOT EXISTS (
                SELECT 1 FROM reachable reachable_cat
                WHERE reachable_cat.category_id = c.category_id
            )

            UNION ALL

            SELECT
                'customers',
                c.customer_id::TEXT,
                'DUPLICATE_NORMALIZED_EMAIL',
                TO_JSONB(c) || JSONB_BUILD_OBJECT(
                    'normalized_email', d.normalized_email,
                    'duplicate_group_size', d.group_size
                )
            FROM customers c
            JOIN duplicate_emails d
              ON LOWER(BTRIM(c.email)) = d.normalized_email

            UNION ALL

            SELECT
                'orders', o.order_id::TEXT,
                'ORDER_STATUS_FORMAT_REVIEW',
                TO_JSONB(o)
            FROM orders o
            WHERE o.status IS NOT NULL
              AND o.status <> LOWER(BTRIM(o.status))
        )
        INSERT INTO data_quality_exceptions (
            source_table,
            source_record_id,
            issue_type,
            original_values
        )
        SELECT
            source_table,
            source_record_id,
            issue_type,
            original_values
        FROM exceptions
        ON CONFLICT (source_table, source_record_id, issue_type)
        DO UPDATE SET
            last_detected_at = NOW(),
            detection_count = data_quality_exceptions.detection_count + 1,
            status = CASE
                WHEN data_quality_exceptions.status = 'resolved'
                THEN 'open'
                ELSE data_quality_exceptions.status
            END,
            resolved_at = CASE
                WHEN data_quality_exceptions.status = 'resolved'
                THEN NULL
                ELSE data_quality_exceptions.resolved_at
            END,
            resolution_note = CASE
                WHEN data_quality_exceptions.status = 'resolved'
                THEN NULL
                ELSE data_quality_exceptions.resolution_note
            END;
END;
$$;
