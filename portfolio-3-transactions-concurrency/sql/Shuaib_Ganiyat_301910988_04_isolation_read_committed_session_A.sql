-- SESSION A (connection 1). READ COMMITTED: each statement sees the latest COMMITTED data.
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT product_id, product_name, quantity_in_stock FROM products WHERE product_id = 1;  -- (1) note the value
-- >>> PAUSE. In Session B run Shuaib_Ganiyat_301910988_04_isolation_read_committed_session_B.sql (it commits). <<<
SELECT product_id, product_name, quantity_in_stock FROM products WHERE product_id = 1;  -- (2) value changed
COMMIT;
