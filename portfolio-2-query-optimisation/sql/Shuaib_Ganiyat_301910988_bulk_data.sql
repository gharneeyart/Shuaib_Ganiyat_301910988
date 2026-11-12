\if :{?sales_n} \else \set sales_n 200000 \endif
\if :{?customers_n} \else \set customers_n 20000 \endif
\if :{?products_n} \else \set products_n 2000 \endif

SELECT setseed(0.42);
\timing on

BEGIN;

-- 16 more categories (20 total)
INSERT INTO categories (category_name)
SELECT 'Category ' || lpad(g::text, 2, '0') FROM generate_series(1, 16) g;

-- customers: 20% wholesale, unique phone numbers 
INSERT INTO customers (customer_name, phone, customer_type)
SELECT 'Customer ' || g,
       '09' || lpad(g::text, 9, '0'),
       CASE WHEN random() < 0.2 THEN 'wholesale' ELSE 'retail' END
FROM generate_series(1, :customers_n) g;

-- products: spread over 20 categories, price 500..90,000, 98% active
-- (stock is set at the end from the ledger)
INSERT INTO products (product_name, category_id, current_price, quantity_in_stock, is_active)
SELECT 'Product ' || lpad(g::text, 5, '0'),
       (SELECT category_id FROM categories ORDER BY category_id OFFSET (g % 20) LIMIT 1),
       round((500 + random() * 89500)::numeric, 2),
       0,
       random() < 0.98
FROM generate_series(1, :products_n) g;

-- plan: one row per new sale
CREATE TEMP TABLE first_ids AS
SELECT (SELECT min(product_id)  FROM products  WHERE product_name LIKE 'Product %') AS p0,
       (SELECT min(customer_id) FROM customers WHERE customer_name LIKE 'Customer %') AS c0;

CREATE TEMP TABLE plan AS
SELECT 1000 + g                                  AS sale_id,
       CASE WHEN random() < 0.2 THEN NULL        -- 20% walk-in sales
            ELSE f.c0 + floor(random() * :customers_n)::int END AS customer_id,
       timestamptz '2026-01-01 08:00+01'
         + random() * interval '304 days'        AS sale_date,
       (random() < 0.03)                         AS is_cancelled,
       1 + floor(random() * 4)::int              AS n_lines,          -- 1..4 lines
       floor(power(random(), 2) * :products_n)::int AS base,          -- skew: low ids are popular
       random()                                  AS pay_r
FROM generate_series(1, :sales_n) g
CROSS JOIN first_ids f;

INSERT INTO sales (sale_id, customer_id, sale_date, sale_status, cancelled_at)
SELECT sale_id, customer_id, sale_date,
       CASE WHEN is_cancelled THEN 'cancelled' ELSE 'completed' END,
       CASE WHEN is_cancelled THEN sale_date + interval '1 hour' END
FROM plan;

-- sale lines: up to 4 DISTINCT products per sale (offset step 37 is coprime
-- with the product count, so k = 1..4 never repeats a product) --------------
INSERT INTO sale_items (sale_item_id, sale_id, product_id, quantity, unit_price)
SELECT 1000 + row_number() OVER (ORDER BY pl.sale_id, k),
       pl.sale_id,
       pr.product_id,
       1 + floor(random() * 5)::int,
       pr.current_price
FROM plan pl
CROSS JOIN first_ids f
CROSS JOIN LATERAL generate_series(1, pl.n_lines) k
JOIN products pr ON pr.product_id = f.p0 + ((pl.base + (k - 1) * 37) % :products_n);

-- payments: 70% paid in full, 20% part-paid on credit (30-90%), 10% unpaid;
-- cancelled sales take no payment 
INSERT INTO payments (sale_id, amount, payment_method, payment_date)
SELECT pl.sale_id,
       round((t.total * CASE WHEN pl.pay_r < 0.70 THEN 1
                              ELSE 0.3 + 0.6 * ((pl.pay_r - 0.70) / 0.20) END)::numeric, 2),
       (ARRAY['cash','transfer','card'])[1 + floor(random() * 3)::int],
       pl.sale_date + interval '5 minutes'
FROM plan pl
JOIN (SELECT sale_id, SUM(line_total) AS total FROM sale_items GROUP BY sale_id) t USING (sale_id)
WHERE NOT pl.is_cancelled AND pl.pay_r < 0.90;

-- ledger: a 'sale' movement per line, a 'return' for lines of cancelled sales -
INSERT INTO inventory_movements (product_id, sale_item_id, movement_type, quantity_change, movement_date)
SELECT si.product_id, si.sale_item_id, 'sale', -si.quantity, s.sale_date
FROM sale_items si JOIN sales s USING (sale_id)
WHERE si.sale_item_id > 1000;

INSERT INTO inventory_movements (product_id, sale_item_id, movement_type, quantity_change, movement_date)
SELECT si.product_id, si.sale_item_id, 'return', si.quantity, s.cancelled_at
FROM sale_items si JOIN sales s USING (sale_id)
WHERE si.sale_item_id > 1000 AND s.sale_status = 'cancelled';

-- opening stock = what was taken out + 1..200 left over, so every product ends
-- with a realistic stock level and low-stock queries are meaningful -----------
INSERT INTO inventory_movements (product_id, movement_type, quantity_change, movement_date, remarks)
SELECT p.product_id, 'opening',
       COALESCE(-SUM(m.quantity_change), 0) + 1 + floor(random() * 200)::int,
       timestamptz '2025-12-31 08:00+01', 'Bulk opening stock'
FROM products p
LEFT JOIN inventory_movements m ON m.product_id = p.product_id
WHERE p.product_name LIKE 'Product %'
GROUP BY p.product_id;

UPDATE products p
SET quantity_in_stock = l.ledger
FROM (SELECT product_id, SUM(quantity_change) AS ledger
      FROM inventory_movements GROUP BY product_id) l
WHERE l.product_id = p.product_id AND p.product_name LIKE 'Product %';

-- keep identity sequences ahead of the explicit ids used above
SELECT setval(pg_get_serial_sequence('sales','sale_id'),                  (SELECT max(sale_id) FROM sales));
SELECT setval(pg_get_serial_sequence('sale_items','sale_item_id'),        (SELECT max(sale_item_id) FROM sale_items));
SELECT setval(pg_get_serial_sequence('payments','payment_id'),            (SELECT max(payment_id) FROM payments));
SELECT setval(pg_get_serial_sequence('inventory_movements','movement_id'),(SELECT max(movement_id) FROM inventory_movements));

COMMIT;

ANALYZE;   -- refresh planner statistics: essential before any EXPLAIN

-- sanity checks 
SELECT 'customers' AS tbl, count(*) FROM customers
UNION ALL SELECT 'products', count(*) FROM products
UNION ALL SELECT 'sales', count(*) FROM sales
UNION ALL SELECT 'sale_items', count(*) FROM sale_items
UNION ALL SELECT 'payments', count(*) FROM payments
UNION ALL SELECT 'inventory_movements', count(*) FROM inventory_movements;
SELECT count(*) AS products_with_drift FROM v_stock_reconciliation WHERE difference <> 0;
