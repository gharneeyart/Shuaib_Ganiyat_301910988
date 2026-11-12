-- SESSION A (connection 1). REPEATABLE READ: the transaction keeps ONE snapshot.
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT product_id, product_name, quantity_in_stock FROM products WHERE product_id = 1;   -- (1) note the value
-- >>> PAUSE. In Session B run 05_repeatable_read_session_B.sql (it commits). <<<
SELECT product_id, product_name, quantity_in_stock FROM products WHERE product_id = 1;   -- (2) SAME value as (1)
COMMIT;
SELECT product_id, product_name, quantity_in_stock FROM products WHERE product_id = 1;   -- (3) new transaction: sees B's change
