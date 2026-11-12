-- DEMO 2: THE FIX (SELECT ... FOR UPDATE). SESSION A (connection 1).
-- Run 07_concurrency_setup.sql first. Order of steps across the two sessions:
--   A1, B1 (B waits), A2, B2

-- A1: read AND lock the product row.
BEGIN;
SELECT quantity_in_stock FROM products WHERE product_id = 6 FOR UPDATE;   -- sees 1, row is now locked

-- >>> Now run B1 in Session B. It will HANG (waiting for A). Screenshot that. Then do A2. <<<

-- A2: sell the unit and deduct stock relative to the current value.
WITH new_sale AS (
    INSERT INTO sales (customer_id, notes) VALUES (1, 'Concurrency demo A') RETURNING sale_id
)
INSERT INTO sale_items (sale_id, product_id, quantity, unit_price)
SELECT sale_id, 6, 1, (SELECT current_price FROM products WHERE product_id = 6) FROM new_sale;
UPDATE products SET quantity_in_stock = quantity_in_stock - 1 WHERE product_id = 6;
COMMIT;                                                                   -- releases the lock: B now continues
