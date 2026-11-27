/*
Kloud Kart - Phase 1: Read-only database reconnaissance
Run AFTER schema.sql and load.sql have completed successfully.
This script does not modify, delete, or clean any records.
It is a profiling snapshot; use the exception scanner for persistent tracking.
*/

\echo '1. ROW COUNTS'
SELECT 'categories' AS table_name, COUNT(*) AS row_count FROM categories
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'inventory_log', COUNT(*) FROM inventory_log
ORDER BY table_name;

\echo '2. COLUMNS, TYPES, NULLABILITY'
SELECT table_name, ordinal_position, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('categories','products','customers','orders','order_items','inventory_log')
ORDER BY table_name, ordinal_position;

\echo '3. PRIMARY KEYS, FOREIGN KEYS, UNIQUE AND CHECK CONSTRAINTS'
SELECT tc.table_name, tc.constraint_name, tc.constraint_type
FROM information_schema.table_constraints AS tc
WHERE tc.table_schema = 'public'
  AND tc.table_name IN ('categories','products','customers','orders','order_items','inventory_log')
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

\echo '4. INDEXES'
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('categories','products','customers','orders','order_items','inventory_log')
ORDER BY tablename, indexname;

\echo '5. NEGATIVE OR ZERO PRODUCT STOCK'
SELECT product_id, product_name, stock_quantity
FROM products
WHERE stock_quantity <= 0
ORDER BY stock_quantity, product_id;

\echo '6. MISSING OR INVALID RELATIONSHIPS'
SELECT 'products_with_missing_category' AS issue, COUNT(*) AS affected_rows
FROM products p LEFT JOIN categories c ON c.category_id = p.category_id
WHERE p.category_id IS NOT NULL AND c.category_id IS NULL
UNION ALL
SELECT 'orders_with_missing_customer', COUNT(*)
FROM orders o LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'items_with_missing_order', COUNT(*)
FROM order_items oi LEFT JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'items_with_missing_product', COUNT(*)
FROM order_items oi LEFT JOIN products p ON p.product_id = oi.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'inventory_logs_with_missing_product', COUNT(*)
FROM inventory_log il LEFT JOIN products p ON p.product_id = il.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'categories_with_missing_parent', COUNT(*)
FROM categories child LEFT JOIN categories parent ON parent.category_id = child.parent_id
WHERE child.parent_id IS NOT NULL AND parent.category_id IS NULL
ORDER BY issue;

\echo '7. DUPLICATE EMAILS (CASE- AND WHITESPACE-NORMALIZED)'
SELECT lower(btrim(email)) AS normalized_email, COUNT(*) AS occurrences
FROM customers
WHERE email IS NOT NULL
GROUP BY lower(btrim(email))
HAVING COUNT(*) > 1
ORDER BY occurrences DESC, normalized_email;

\echo '8. ORDER STATUS VARIANTS'
SELECT status, COUNT(*) AS order_count
FROM orders
GROUP BY status
ORDER BY order_count DESC, status;

\echo '9. NULLS AND INVALID NUMERIC VALUES'
SELECT 'products_missing_category' AS issue, COUNT(*) AS affected_rows FROM products WHERE category_id IS NULL
UNION ALL SELECT 'order_items_missing_unit_price', COUNT(*) FROM order_items WHERE unit_price IS NULL
UNION ALL SELECT 'order_items_nonpositive_quantity', COUNT(*) FROM order_items WHERE quantity <= 0
UNION ALL SELECT 'order_items_negative_unit_price', COUNT(*) FROM order_items WHERE unit_price < 0
UNION ALL SELECT 'products_negative_price', COUNT(*) FROM products WHERE price < 0
UNION ALL SELECT 'inventory_zero_change', COUNT(*) FROM inventory_log WHERE change_qty = 0
ORDER BY issue;

\echo '10. DATE RANGES'
SELECT 'products.created_at' AS field_name, MIN(created_at) AS earliest_value, MAX(created_at) AS latest_value FROM products
UNION ALL SELECT 'customers.registered_at', MIN(registered_at), MAX(registered_at) FROM customers
UNION ALL SELECT 'orders.order_date', MIN(order_date), MAX(order_date) FROM orders
UNION ALL SELECT 'inventory_log.created_at', MIN(created_at), MAX(created_at) FROM inventory_log;

\echo '11. ORDER TOTAL VS LINE-ITEM EXTENSION (NULL PRICES EXCLUDED FROM CALCULATION)'
WITH item_totals AS (
    SELECT order_id,
           SUM(quantity * unit_price) AS calculated_total,
           COUNT(*) FILTER (WHERE unit_price IS NULL) AS missing_price_lines
    FROM order_items
    GROUP BY order_id
)
SELECT o.order_id, o.total_amount, it.calculated_total, it.missing_price_lines,
       (o.total_amount - it.calculated_total) AS difference
FROM orders o
JOIN item_totals it ON it.order_id = o.order_id
WHERE it.missing_price_lines = 0
  AND ABS(o.total_amount - it.calculated_total) > 0.01
ORDER BY ABS(o.total_amount - it.calculated_total) DESC
LIMIT 50;

\echo '12. CATEGORY TREE: SELF-PARENT AND MISSING-PARENT CHECKS'
SELECT category_id, category_name, parent_id
FROM categories
WHERE category_id = parent_id
   OR (parent_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM categories p WHERE p.category_id = categories.parent_id
   ))
ORDER BY category_id;
