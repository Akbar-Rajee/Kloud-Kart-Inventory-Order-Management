SELECT
    product_id,
    product_name,
    stock_quantity
FROM products
WHERE stock_quantity < 0;