-- DEMO 1: THE PROBLEM (no locking). SESSION A (connection 1).
-- Run Shuaib_Ganiyat_301910988_07_concurrency_setup.sql first. Order of steps across the two sessions:
--   A1, B1, A2, B2

-- A1
BEGIN;
SELECT quantity_in_stock FROM products WHERE product_id = 6;  -- sees 1: "enough stock"

-- >>> Now run B1 in Session B, then come back for A2. <<<

-- A2: sell the unit and write the value calculated from the earlier read (1 - 1 = 0).
WITH new_sale AS (
    INSERT INTO sales (customer_id, notes) VALUES (1, 'Concurrency demo A') RETURNING sale_id
)
INSERT INTO sale_items (sale_id, product_id, quantity, unit_price)
SELECT sale_id, 6, 1, (SELECT current_price FROM products WHERE product_id = 6) FROM new_sale;
UPDATE products SET quantity_in_stock = 0 WHERE product_id = 6;
COMMIT;
