-- 1. BEFORE: row counts and stock.
SELECT (SELECT count(*) FROM sales)               AS sales,
       (SELECT count(*) FROM sale_items)          AS sale_items,
       (SELECT count(*) FROM payments)            AS payments,
       (SELECT count(*) FROM inventory_movements) AS movements,
       (SELECT quantity_in_stock FROM products WHERE product_id = 1) AS stock_product_1;

-- 2. The failing sale. Expected: ERROR:  Insufficient stock. Available: ..., requested: 9999
SELECT record_sale(1, 1, 9999);

-- 3. AFTER: every number must be identical to step 1.
SELECT (SELECT count(*) FROM sales)               AS sales,
       (SELECT count(*) FROM sale_items)          AS sale_items,
       (SELECT count(*) FROM payments)            AS payments,
       (SELECT count(*) FROM inventory_movements) AS movements,
       (SELECT quantity_in_stock FROM products WHERE product_id = 1) AS stock_product_1;
