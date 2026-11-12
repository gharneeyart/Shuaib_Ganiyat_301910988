-- ---------------------------------------------------------------------------
-- Experiment 1: composite index. Target query: Q7 (stock history of one product)
-- ---------------------------------------------------------------------------
-- EXPLAIN (ANALYZE, BUFFERS)  <paste Q7 here>
CREATE INDEX idx_inventory_product_date ON inventory_movements(product_id, movement_date DESC);
ANALYZE inventory_movements;
-- EXPLAIN (ANALYZE, BUFFERS)  <paste Q7 again>

-- ---------------------------------------------------------------------------
-- Experiment 2: single-column foreign-key index. Target query: Q8
-- ---------------------------------------------------------------------------
-- EXPLAIN (ANALYZE, BUFFERS)  <paste Q8 here>
CREATE INDEX idx_sale_items_product_id ON sale_items(product_id);
ANALYZE sale_items;
-- EXPLAIN (ANALYZE, BUFFERS)  <paste Q8 again>

-- ---------------------------------------------------------------------------
-- Experiment 3: foreign-key index for an anti-join. Target query: Q6
-- ---------------------------------------------------------------------------
-- EXPLAIN (ANALYZE, BUFFERS)  <paste Q6 here>
CREATE INDEX idx_sales_customer_id ON sales(customer_id);
ANALYZE sales;
-- EXPLAIN (ANALYZE, BUFFERS)  <paste Q6 again>

-- ---------------------------------------------------------------------------
-- Experiment 4: partial index. Target query: Q2 (low stock)
-- ---------------------------------------------------------------------------
-- EXPLAIN (ANALYZE, BUFFERS)  <paste Q2 here>
CREATE INDEX idx_products_low_stock ON products(quantity_in_stock, product_name)
    WHERE is_active AND quantity_in_stock <= 15;
ANALYZE products;
-- EXPLAIN (ANALYZE, BUFFERS)  <paste Q2 again>

-- ---------------------------------------------------------------------------
-- Experiment 5: an index that may NOT help. Target query: Q3 (June = ~10% of sales)
-- ---------------------------------------------------------------------------
-- EXPLAIN (ANALYZE, BUFFERS)  <paste Q3 here>
CREATE INDEX idx_sales_sale_date ON sales(sale_date);
ANALYZE sales;
-- EXPLAIN (ANALYZE, BUFFERS)  <paste Q3 again>

