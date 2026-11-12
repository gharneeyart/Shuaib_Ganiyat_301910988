-- DEMO 1: THE PROBLEM (no locking). SESSION B (connection 2).
-- Steps: A1, B1, A2, B2 (see 08_lost_update_session_A.sql).

-- B1 (run after A1, before A2)
BEGIN;
SELECT quantity_in_stock FROM products WHERE product_id = 6;      -- ALSO sees 1: A has not committed yet

-- >>> Now go back and run A2 (including COMMIT) in Session A, then run B2. <<<

-- B2: sells the same unit.
WITH new_sale AS (
    INSERT INTO sales (customer_id, notes) VALUES (2, 'Concurrency demo B') RETURNING sale_id
)
INSERT INTO sale_items (sale_id, product_id, quantity, unit_price)
SELECT sale_id, 6, 1, (SELECT current_price FROM products WHERE product_id = 6) FROM new_sale;
UPDATE products SET quantity_in_stock = 0 WHERE product_id = 6;
COMMIT;

-- CHECK THE DAMAGE (either session): two sales of a product that had ONE unit.
SELECT s.notes, si.quantity FROM sales s JOIN sale_items si USING (sale_id)
WHERE s.notes LIKE 'Concurrency demo%' ORDER BY s.notes;                  -- 2 rows, 1 unit each
SELECT quantity_in_stock FROM products WHERE product_id = 6;             -- 0, not -1: the second write overwrote the first
