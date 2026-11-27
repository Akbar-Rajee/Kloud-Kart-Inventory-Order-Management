-- ============================================================
-- Kloud Kart: Read-only integrity summary
-- Run after schema load and project setup. This script does not repair data.
-- This compact, independent snapshot intentionally overlaps selected scanner
-- checks so operators can compare source-table counts without changing the
-- persistent exception register or its investigation workflow.
-- ============================================================

SELECT 'negative_stock_products' AS check_name, COUNT(*) AS exception_count
FROM products WHERE stock_quantity < 0
UNION ALL
SELECT 'orphan_order_items', COUNT(*)
FROM order_items oi
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = oi.order_id)
UNION ALL
SELECT 'order_customer_missing', COUNT(*)
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id)
UNION ALL
SELECT 'inventory_product_missing', COUNT(*)
FROM inventory_log il
WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.product_id = il.product_id)
UNION ALL
SELECT 'null_order_item_price', COUNT(*)
FROM order_items WHERE unit_price IS NULL
UNION ALL
SELECT 'nonpositive_order_item_quantity', COUNT(*)
FROM order_items WHERE quantity IS NULL OR quantity <= 0
UNION ALL
SELECT 'negative_order_item_price', COUNT(*)
FROM order_items WHERE unit_price < 0
UNION ALL
SELECT 'negative_product_price', COUNT(*)
FROM products WHERE price < 0
ORDER BY check_name;
