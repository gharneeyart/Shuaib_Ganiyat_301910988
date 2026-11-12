-- Concurrency demos: reset. Run before each of the two demos (08 and 09).
-- Scenario: product 6 has exactly ONE unit left and two customers try to buy it.

DELETE FROM sale_items WHERE sale_id IN (SELECT sale_id FROM sales WHERE notes LIKE 'Concurrency demo%');
DELETE FROM sales WHERE notes LIKE 'Concurrency demo%';

DO $$
DECLARE led INTEGER;
BEGIN
    SELECT COALESCE(SUM(quantity_change), 0) INTO led FROM inventory_movements WHERE product_id = 6;
    UPDATE products SET quantity_in_stock = 1 WHERE product_id = 6;
    IF led <> 1 THEN      -- put the ledger in step with the counter (the demos skip ledger rows)
        INSERT INTO inventory_movements (product_id, movement_type, quantity_change, remarks)
        VALUES (6, 'adjustment', 1 - led, 'Concurrency demo setup');
    END IF;
END $$;

SELECT product_id, product_name, quantity_in_stock FROM products WHERE product_id = 6;   -- must show 1
