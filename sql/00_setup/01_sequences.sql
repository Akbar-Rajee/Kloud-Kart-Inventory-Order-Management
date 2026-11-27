-- ============================================================
-- Kloud Kart: ID sequence setup
-- Run AFTER schema.sql and load.sql.
-- Run BEFORE accepting new orders.
-- ============================================================

BEGIN;

-- Orders
CREATE SEQUENCE IF NOT EXISTS orders_order_id_seq;

ALTER TABLE orders
    ALTER COLUMN order_id
    SET DEFAULT nextval('orders_order_id_seq');

-- With is_called=false, the next nextval returns this value (MAX + 1).
SELECT setval(
    'orders_order_id_seq',
    COALESCE((SELECT MAX(order_id) FROM orders), 0) + 1,
    false
);

ALTER SEQUENCE orders_order_id_seq
    OWNED BY orders.order_id;


-- Order items
CREATE SEQUENCE IF NOT EXISTS order_items_order_item_id_seq;

ALTER TABLE order_items
    ALTER COLUMN order_item_id
    SET DEFAULT nextval('order_items_order_item_id_seq');

-- The same false flag makes the next nextval return MAX + 1 exactly.
SELECT setval(
    'order_items_order_item_id_seq',
    COALESCE((SELECT MAX(order_item_id) FROM order_items), 0) + 1,
    false
);

ALTER SEQUENCE order_items_order_item_id_seq
    OWNED BY order_items.order_item_id;


-- Inventory log
CREATE SEQUENCE IF NOT EXISTS inventory_log_log_id_seq;

ALTER TABLE inventory_log
    ALTER COLUMN log_id
    SET DEFAULT nextval('inventory_log_log_id_seq');

-- The same false flag makes the next nextval return MAX + 1 exactly.
SELECT setval(
    'inventory_log_log_id_seq',
    COALESCE((SELECT MAX(log_id) FROM inventory_log), 0) + 1,
    false
);

ALTER SEQUENCE inventory_log_log_id_seq
    OWNED BY inventory_log.log_id;

COMMIT;
