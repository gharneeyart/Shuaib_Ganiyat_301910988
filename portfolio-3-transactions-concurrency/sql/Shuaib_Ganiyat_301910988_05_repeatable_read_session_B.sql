-- SESSION B (connection 2). Run while Session A's REPEATABLE READ transaction is open.
BEGIN;
UPDATE products SET quantity_in_stock = quantity_in_stock - 1
WHERE product_id = 1 AND quantity_in_stock >= 1;
COMMIT;
