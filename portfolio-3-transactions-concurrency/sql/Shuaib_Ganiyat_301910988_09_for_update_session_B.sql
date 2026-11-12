-- DEMO 2: THE FIX (SELECT ... FOR UPDATE). SESSION B (connection 2).
-- Steps: A1, B1 (B waits), A2, B2 (see 09_for_update_session_A.sql).

-- B1 (run after A1): the SELECT ... FOR UPDATE waits until A commits or rolls back.
BEGIN;
SELECT quantity_in_stock FROM products WHERE product_id = 6 FOR UPDATE;
-- After A commits this returns 0 (not 1): B sees the committed value. The
-- application check "stock >= 1" fails, so B does NOT sell.

-- B2: stock is 0, so abandon the sale.
ROLLBACK;

-- CHECK: exactly one sale, stock 0.
SELECT s.notes, si.quantity FROM sales s JOIN sale_items si USING (sale_id)
WHERE s.notes LIKE 'Concurrency demo%';                                  -- 1 row (A only)
SELECT quantity_in_stock FROM products WHERE product_id = 6;             -- 0
