\set ON_ERROR_STOP off

-- 1. Customers
-- NEGATIVE TESTS
-- customer_type must be 'retail' or 'wholesale'. Expected: customers_customer_type_check (23514)
INSERT INTO customers (customer_name, customer_type) VALUES ('Sade Rahman', 'vip');

-- phone is unique. Expected: customers_phone_key (23505)
INSERT INTO customers (customer_name, phone) VALUES ('Sade Rahman', '08030000001');

-- customer_name cannot be NULL. Expected: not-null violation on customer_name (23502)
INSERT INTO customers (customer_name) VALUES (NULL);

-- POSITIVE TESTS
BEGIN;
-- customer with a phone number
INSERT INTO customers (customer_name, phone) VALUES ('Sofiat Adigun', '08039998888');
-- several customers may have no phone (NULLs are not equal in a UNIQUE index)
INSERT INTO customers (customer_name) VALUES ('NoPhone A'), ('NoPhone B');
ROLLBACK;

-- 2. Categories and products
-- NEGATIVE TESTS
-- category_name is unique. Expected: categories_category_name_key (23505)
INSERT INTO categories (category_name) VALUES ('Grains');

-- negative price. Expected: products_current_price_check (23514)
INSERT INTO products (product_name, category_id, current_price) VALUES ('X', 1, -1);

-- negative stock. Expected: products_quantity_in_stock_check (23514)
UPDATE products SET quantity_in_stock = -1 WHERE product_id = 1;

-- non-existent category. Expected: products_category_id_fkey (23503)
INSERT INTO products (product_name, category_id, current_price) VALUES ('X', 999, 10);

-- a category that has products cannot be deleted. Expected: RESTRICT on products_category_id_fkey (23001)
DELETE FROM categories WHERE category_id = 1;

-- POSITIVE TESTS
BEGIN;
-- boundary values: zero price and zero stock are allowed
INSERT INTO products (product_name, category_id, current_price, quantity_in_stock)
VALUES ('Promo Salt', 1, 0.00, 0);
-- new unique category
INSERT INTO categories (category_name) VALUES ('Noodles');
ROLLBACK;

-- 3. Sales
-- NEGATIVE TESTS
-- invalid status. Expected: sales_sale_status_check (23514)
INSERT INTO sales (sale_status) VALUES ('pending');

-- cancelled sale must have cancelled_at. Expected: ck_cancel_consistent (23514)
INSERT INTO sales (sale_status) VALUES ('cancelled');

-- completed sale must not have cancelled_at. Expected: ck_cancel_consistent (23514)
INSERT INTO sales (sale_status, cancelled_at) VALUES ('completed', now());

-- non-existent customer. Expected: sales_customer_id_fkey (23503)
INSERT INTO sales (customer_id) VALUES (999);

-- a sale with items/payments cannot be deleted. Expected: RESTRICT on sale_items_sale_id_fkey (23001)
DELETE FROM sales WHERE sale_id = 1;

-- a customer with sales cannot be deleted. Expected: RESTRICT on sales_customer_id_fkey (23001)
DELETE FROM customers WHERE customer_id = 1;

-- POSITIVE TESTS
BEGIN;
-- walk-in sale: customer_id is optional (NULL)
INSERT INTO sales (customer_id) VALUES (NULL);
-- sale for an existing customer
INSERT INTO sales (customer_id) VALUES (2);
ROLLBACK;

-- 4. Sale items
-- NEGATIVE TESTS
-- quantity must be > 0. Expected: sale_items_quantity_check (23514)
INSERT INTO sale_items (sale_id, product_id, quantity, unit_price) VALUES (1, 4, 0, 10);

-- unit price cannot be negative. Expected: sale_items_unit_price_check (23514)
INSERT INTO sale_items (sale_id, product_id, quantity, unit_price) VALUES (1, 4, 1, -10);

-- same product twice on one sale. Expected: uq_sale_product (23505)
INSERT INTO sale_items (sale_id, product_id, quantity, unit_price) VALUES (1, 3, 1, 10);

-- line_total is generated and cannot be written. Expected: generated column error (428C9)
INSERT INTO sale_items (sale_id, product_id, quantity, unit_price, line_total) VALUES (1, 4, 1, 10, 999);

-- non-existent product. Expected: sale_items_product_id_fkey (23503)
INSERT INTO sale_items (sale_id, product_id, quantity, unit_price) VALUES (1, 999, 1, 10);

-- a product that has been sold cannot be deleted. Expected: RESTRICT on sale_items_product_id_fkey (23001)
DELETE FROM products WHERE product_id = 1;

-- POSITIVE TEST
BEGIN;
-- a valid line; line_total is calculated by the database (3 x 2000 = 6000)
INSERT INTO sale_items (sale_id, product_id, quantity, unit_price) VALUES (1, 4, 3, 2000.00);
SELECT sale_item_id, quantity, unit_price, line_total FROM sale_items WHERE sale_id = 1 AND product_id = 4;
ROLLBACK;

-- 5. Payments
-- NEGATIVE TESTS
-- amount must be > 0. Expected: payments_amount_check (23514)
INSERT INTO payments (sale_id, amount, payment_method) VALUES (1, 0, 'cash');

-- invalid payment method. Expected: payments_payment_method_check (23514)
INSERT INTO payments (sale_id, amount, payment_method) VALUES (1, 10, 'crypto');

-- non-existent sale. Expected: payments_sale_id_fkey (23503)
INSERT INTO payments (sale_id, amount, payment_method) VALUES (999, 10, 'cash');

-- POSITIVE TESTS
BEGIN;
-- smallest positive amount
INSERT INTO payments (sale_id, amount, payment_method) VALUES (2, 0.01, 'cash');
-- a second (partial) payment on the same sale, using transfer and card
INSERT INTO payments (sale_id, amount, payment_method) VALUES (2, 5000, 'transfer');
INSERT INTO payments (sale_id, amount, payment_method) VALUES (2, 12000, 'card');
ROLLBACK;

-- 6. Inventory movements
-- NEGATIVE TESTS
-- a sale movement must be negative. Expected: ck_movement_sign (23514)
INSERT INTO inventory_movements (product_id, sale_item_id, movement_type, quantity_change)
VALUES (1, 3, 'sale', 3);

-- a restock movement must be positive. Expected: ck_movement_sign (23514)
INSERT INTO inventory_movements (product_id, movement_type, quantity_change)
VALUES (1, 'restock', -3);

-- quantity_change cannot be zero. Expected: inventory_movements_quantity_change_check (23514)
INSERT INTO inventory_movements (product_id, movement_type, quantity_change)
VALUES (1, 'adjustment', 0);

-- a sale movement must reference a sale line. Expected: ck_movement_link (23514)
INSERT INTO inventory_movements (product_id, movement_type, quantity_change)
VALUES (1, 'sale', -1);

-- a restock must NOT reference a sale line. Expected: ck_movement_link (23514)
INSERT INTO inventory_movements (product_id, sale_item_id, movement_type, quantity_change)
VALUES (1, 3, 'restock', 5);

-- a second sale movement for the same sale line. Expected: uq_one_sale_movement_per_item (23505)
INSERT INTO inventory_movements (product_id, sale_item_id, movement_type, quantity_change)
VALUES (3, 1, 'sale', -1);

-- unknown movement type. Expected: 23514 (ck_movement_sign fires first; the movement_type CHECK also rejects it)
INSERT INTO inventory_movements (product_id, movement_type, quantity_change)
VALUES (1, 'theft', -1);

-- POSITIVE TESTS
BEGIN;
-- a return may reference the same sale line as its sale movement
INSERT INTO inventory_movements (product_id, sale_item_id, movement_type, quantity_change)
VALUES (3, 1, 'return', 1);
-- a restock with no sale line
INSERT INTO inventory_movements (product_id, movement_type, quantity_change)
VALUES (1, 'restock', 10);
ROLLBACK;

-- 7. Views
-- counter = ledger for every product. Expected: 0 rows
SELECT * FROM v_stock_reconciliation WHERE difference <> 0;

-- sale 1 is fully paid. Expected: outstanding = 0
SELECT sale_id, sale_total, amount_paid, outstanding FROM v_sale_balances WHERE sale_id = 1;
