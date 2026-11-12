-- =========================================================================
-- Q1  Credit exposure: customers who still owe money, largest debt first (CTEs + HAVING).
-- Business question: who must the manager chase for payment?
-- Cancelled sales are excluded (they were never a debt).
-- =========================================================================
WITH sale_totals AS (
    SELECT sale_id, SUM(line_total) AS total_amount
    FROM sale_items GROUP BY sale_id
),
paid AS (
    SELECT sale_id, SUM(amount) AS amount_paid
    FROM payments GROUP BY sale_id
)
SELECT c.customer_id, c.customer_name, c.customer_type,
       COUNT(*)                                                    AS credit_sales,
       SUM(st.total_amount - COALESCE(pd.amount_paid, 0))::NUMERIC(14,2) AS outstanding
FROM sales s
JOIN customers c    ON c.customer_id = s.customer_id
JOIN sale_totals st ON st.sale_id    = s.sale_id
LEFT JOIN paid pd   ON pd.sale_id    = s.sale_id
WHERE s.sale_status = 'completed'
GROUP BY c.customer_id, c.customer_name, c.customer_type
HAVING SUM(st.total_amount - COALESCE(pd.amount_paid, 0)) > 0
ORDER BY outstanding DESC
LIMIT 10;

-- =========================================================================
-- Q2  Reorder list: active products at or below 15 units.
-- Business question: what must be restocked now?
-- =========================================================================
SELECT product_id, product_name, quantity_in_stock
FROM products
WHERE is_active AND quantity_in_stock <= 15
ORDER BY quantity_in_stock, product_name;

-- =========================================================================
-- Q3  Daily revenue for one month (date range + join + aggregate).
-- Business question: how did June 2026 trade, day by day?
-- =========================================================================
SELECT date_trunc('day', s.sale_date)::date AS day,
       COUNT(DISTINCT s.sale_id)            AS sales,
       SUM(si.line_total)::NUMERIC(14,2)    AS revenue
FROM sales s
JOIN sale_items si ON si.sale_id = s.sale_id
WHERE s.sale_date >= TIMESTAMPTZ '2026-06-01 00:00:00+01'
  AND s.sale_date <  TIMESTAMPTZ '2026-07-01 00:00:00+01'
  AND s.sale_status = 'completed'
GROUP BY 1
ORDER BY 1;

-- =========================================================================
-- Q4  Top 10 customers by lifetime purchases (3-table join + aggregate).
-- Business question: who are the best customers (for loyalty or wholesale terms)?
-- =========================================================================
SELECT c.customer_id, c.customer_name, c.customer_type,
       SUM(si.line_total)::NUMERIC(14,2) AS purchase_total
FROM customers c
JOIN sales s       ON s.customer_id = c.customer_id AND s.sale_status = 'completed'
JOIN sale_items si ON si.sale_id    = s.sale_id
GROUP BY c.customer_id, c.customer_name, c.customer_type
ORDER BY purchase_total DESC
LIMIT 10;

-- =========================================================================
-- Q5  Best 3 products per category by revenue (window function over a CTE).
-- Business question: what sells best in each category?
-- =========================================================================
WITH revenue AS (
    SELECT p.category_id, p.product_id, p.product_name,
           SUM(si.line_total) AS revenue
    FROM sale_items si
    JOIN products p ON p.product_id = si.product_id
    JOIN sales s    ON s.sale_id    = si.sale_id AND s.sale_status = 'completed'
    GROUP BY p.category_id, p.product_id, p.product_name
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY revenue DESC) AS rn
    FROM revenue
)
SELECT c.category_name, r.product_name, r.revenue::NUMERIC(14,2), r.rn AS rank_in_category
FROM ranked r
JOIN categories c ON c.category_id = r.category_id
WHERE r.rn <= 3
ORDER BY c.category_name, r.rn;

-- =========================================================================
-- Q6  Customers who have never bought anything (anti-join with NOT EXISTS).
-- Business question: which registered customers should get a marketing nudge?
-- =========================================================================
SELECT c.customer_id, c.customer_name
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM sales s WHERE s.customer_id = c.customer_id)
ORDER BY c.customer_id
LIMIT 20;

-- =========================================================================
-- Q7  Latest 20 stock movements of one product (equality + sort + LIMIT).
-- Business question: why did this product's stock change? (audit)
-- =========================================================================
SELECT movement_id, movement_type, quantity_change, movement_date
FROM inventory_movements
WHERE product_id = 7
ORDER BY movement_date DESC
LIMIT 20;

-- =========================================================================
-- Q8  Recent sales lines of one slow-moving product (selective equality on an FK column).
-- Business question: who bought product 1200 and when?
-- =========================================================================
SELECT si.sale_id, s.sale_date, si.quantity, si.unit_price
FROM sale_items si
JOIN sales s ON s.sale_id = si.sale_id
WHERE si.product_id = 1200
ORDER BY s.sale_date DESC
LIMIT 20;

