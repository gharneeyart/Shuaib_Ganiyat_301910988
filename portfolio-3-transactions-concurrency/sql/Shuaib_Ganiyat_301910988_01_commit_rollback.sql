-- 0. BEFORE: counter and ledger of product 1 (difference must be 0).
SELECT product_id, counter, ledger, difference
FROM v_stock_reconciliation WHERE product_id = 1;

-- A. COMMIT: restock 3 units. Both changes become permanent together.
BEGIN;
UPDATE products SET quantity_in_stock = quantity_in_stock + 3 WHERE product_id = 1;
INSERT INTO inventory_movements (product_id, movement_type, quantity_change, remarks)
VALUES (1, 'restock', 3, 'Portfolio 3 commit demo');
SELECT product_id, counter, ledger, difference
FROM v_stock_reconciliation WHERE product_id = 1;
COMMIT;

SELECT product_id, counter, ledger, difference
FROM v_stock_reconciliation WHERE product_id = 1;

-- B. ROLLBACK: "restock" 100 units, then change our mind. NEITHER change survives.
BEGIN;
UPDATE products SET quantity_in_stock = quantity_in_stock + 100 WHERE product_id = 1;
INSERT INTO inventory_movements (product_id, movement_type, quantity_change, remarks)
VALUES (1, 'restock', 100, 'Portfolio 3 rollback demo');
SELECT product_id, counter, ledger, difference
FROM v_stock_reconciliation WHERE product_id = 1;
ROLLBACK;

SELECT product_id, counter, ledger, difference
FROM v_stock_reconciliation WHERE product_id = 1;
