CREATE OR REPLACE FUNCTION record_sale(
    p_product_id  BIGINT,
    p_customer_id BIGINT,
    p_quantity    INTEGER
) RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    v_price        NUMERIC(12,2);
    v_stock        INTEGER;
    v_sale_id      BIGINT;
    v_sale_item_id BIGINT;
BEGIN
  -- FOR UPDATE locks this product row until the transaction ends, so two
  -- sales of the same product cannot check and change stock at the same time.
    SELECT current_price, quantity_in_stock
      INTO v_price, v_stock
    FROM products
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % does not exist', p_product_id;
    END IF;

    IF v_stock < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, requested: %', v_stock, p_quantity;
    END IF;

    INSERT INTO sales (customer_id, notes)
    VALUES (p_customer_id, 'Portfolio 3 transaction test')
    RETURNING sale_id INTO v_sale_id;

    INSERT INTO sale_items (sale_id, product_id, quantity, unit_price)
    VALUES (v_sale_id, p_product_id, p_quantity, v_price)
    RETURNING sale_item_id INTO v_sale_item_id;

    UPDATE products
    SET quantity_in_stock = quantity_in_stock - p_quantity
    WHERE product_id = p_product_id;

    INSERT INTO inventory_movements (product_id, sale_item_id, movement_type, quantity_change, remarks)
    VALUES (p_product_id, v_sale_item_id, 'sale', -p_quantity, 'Portfolio 3 transaction test');

    INSERT INTO payments (sale_id, amount, payment_method, reference)
    VALUES (v_sale_id, v_price * p_quantity, 'cash', 'PORTFOLIO-TEST');

    RETURN v_sale_id;
END $$;

-- Successful sales. Run once each (every run creates another test sale).
BEGIN;
SELECT record_sale(1, 1, 1) AS sale_id;
SELECT record_sale(2, 2, 3) AS sale_id;  -- 3 units of product 2: payment must be 3 x price
COMMIT;

-- Verify: totals match payments, stock and ledger agree.
SELECT s.sale_id, si.product_id, si.quantity, si.unit_price, si.line_total, p.amount AS paid
FROM sales s
JOIN sale_items si ON si.sale_id = s.sale_id
JOIN payments p    ON p.sale_id  = s.sale_id
WHERE s.notes = 'Portfolio 3 transaction test'
ORDER BY s.sale_id;

SELECT * FROM v_stock_reconciliation WHERE product_id IN (1, 2) ORDER BY product_id;
