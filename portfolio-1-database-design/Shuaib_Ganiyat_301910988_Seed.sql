INSERT INTO categories (category_name) VALUES
('Grains'), ('Cooking Essentials'), ('Beverages'), ('Household');

INSERT INTO customers (customer_name, phone, customer_type) VALUES
('Amina Yusuf', '08030000001', 'retail'),
('Bello Traders', '08030000002', 'wholesale'),
('Chika Okafor', '08030000003', 'retail'),
('Dayo Stores', '08030000004', 'wholesale');

INSERT INTO products (product_name, category_id, current_price, quantity_in_stock) VALUES
('Rice 50kg', 1, 85000.00, 23),
('Beans 25kg', 1, 42000.00, 17),
('Vegetable Oil 5L', 2, 12500.00, 28),
('Tomato Paste Carton', 2, 18000.00, 12),
('Malt Drink Pack', 3, 9500.00, 19),
('Laundry Soap Carton', 4, 14500.00, 15);

INSERT INTO sales (customer_id, sale_date, notes) VALUES
(1, '2026-10-01 10:00:00+01', 'Retail purchase'),
(2, '2026-10-02 12:30:00+01', 'Wholesale purchase on partial credit');

INSERT INTO sale_items (sale_id, product_id, quantity, unit_price) VALUES
(1, 3, 2, 12500.00),
(1, 5, 1, 9500.00),
(2, 1, 2, 85000.00),
(2, 2, 1, 42000.00);

INSERT INTO payments (sale_id, amount, payment_method, reference) VALUES
(1, 34500.00, 'cash', 'CASH-0001'),
(2, 100000.00, 'transfer', 'TRF-0002');

INSERT INTO inventory_movements
(product_id, sale_item_id, movement_type, quantity_change, remarks) VALUES
(1, NULL, 'opening', 25, 'Opening stock'),
(2, NULL, 'opening', 18, 'Opening stock'),
(3, NULL, 'opening', 30, 'Opening stock'),
(4, NULL, 'opening', 12, 'Opening stock'),
(5, NULL, 'opening', 20, 'Opening stock'),
(6, NULL, 'opening', 15, 'Opening stock'),
(3, 1, 'sale', -2, 'Sale 1'),
(5, 2, 'sale', -1, 'Sale 1'),
(1, 3, 'sale', -2, 'Sale 2'),
(2, 4, 'sale', -1, 'Sale 2');
