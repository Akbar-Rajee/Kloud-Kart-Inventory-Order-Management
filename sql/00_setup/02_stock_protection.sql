
-- ============================================================
-- Kloud Kart: Stock protection
-- Allows historical exceptions but protects future writes.
-- ============================================================

ALTER TABLE products
ADD CONSTRAINT products_stock_nonnegative
CHECK (stock_quantity >= 0)
NOT VALID;
