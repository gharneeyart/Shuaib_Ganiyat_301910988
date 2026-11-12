-- SESSION A (connection 1). REPEATABLE READ and a write conflict.
-- Use 05_repeatable_read_session_B.sql as Session B.
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT product_id, quantity_in_stock FROM products WHERE product_id = 1;   -- (1) snapshot is taken here
-- >>> PAUSE. Session B: run 05_repeatable_read_session_B.sql (it commits). <<<
UPDATE products SET quantity_in_stock = quantity_in_stock - 1 WHERE product_id = 1;   -- (2)
-- Expected: ERROR:  could not serialize access due to concurrent update
-- PostgreSQL refuses to let A overwrite a row that changed after A's snapshot.
ROLLBACK;   -- the transaction is aborted; the application must RETRY it from the start
