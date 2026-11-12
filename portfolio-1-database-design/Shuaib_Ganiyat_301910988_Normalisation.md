# Normalisation of the Adetwin Stores Database

## 1. Introduction

Database normalisation is the process of structuring database tables to reduce unnecessary duplication and prevent insertion, update, and deletion anomalies.

The Adetwin Stores database applies First Normal Form (1NF), Second Normal Form (2NF), Third Normal Form (3NF) and Boyce-Codd Normal Form (BCNF), and documents where it deliberately departs from them.

## 2. Starting Point: An Unnormalised Receipt

A paper receipt at the store can be written as one table, with one row per product bought:

| sale_id | sale_date | customer_name | customer_phone | customer_type | product_name | category_name | quantity | unit_price | payments |
|---:|---|---|---|---|---|---|---:|---:|---|
| 2 | 2026-06-10 | Bello Traders | 08030000002 | wholesale | Rice 50kg | Grains | 2 | 85000 | 100000 transfer |
| 2 | 2026-06-10 | Bello Traders | 08030000002 | wholesale | Beans 25kg | Grains | 1 | 42000 | 100000 transfer |

This breaks the rules of relational design: the `payments` cell can hold several values (for example "34500 cash; 20000 transfer"), and the customer, product and category details are repeated on every row.

It also causes three anomalies:

- **Update:** Bello Traders changes phone number, so every row of every sale must be changed or the data contradicts itself.
- **Insert:** a new product cannot be added until it is sold, and a new customer cannot be registered until they buy.
- **Delete:** deleting the only sale of a product also deletes the fact that the product exists, and its price.

## 3. First Normal Form (1NF)

A table is in 1NF when every column holds a single atomic value and there are no repeating groups.

The `payments` cell is moved out of the receipt: each payment becomes one row in `PAYMENTS` (`payment_id`, `sale_id`, `amount`, `payment_method`, `payment_date`). Each product bought stays one row, now in `SALE_ITEMS`. A sale can have any number of items or payments without changing the table structure.

## 4. Second Normal Form (2NF)

A table is in 2NF when it is in 1NF and every non-key attribute depends on the whole key. This matters only when a key has more than one column.

Candidate-key analysis of the sale-line table as first designed, keyed on `(sale_id, product_id)`:

-   `sale_date`, `customer_name`, `customer_phone` and `customer_type` depend on `sale_id` alone. That is a partial dependency, so they move to `SALES` and `CUSTOMERS`.
-   `product_name`, `category_name` and `current_price` depend on `product_id` alone. That is also a partial dependency, so they stay in `PRODUCTS` and `CATEGORIES`.
-   `quantity` and `unit_price` depend on both parts of the key, so they stay in `SALE_ITEMS`.

The implemented design gives each line a surrogate key (`sale_item_id`) and keeps `(sale_id, product_id)` as a UNIQUE constraint (`uq_sale_product`), which records the business rule "one line per product per sale". All non-key attributes depend on the whole of that candidate key.

`SALE_ITEMS.unit_price` is deliberately kept even though `PRODUCTS` has `current_price`. It is a different fact: the price charged at the time of sale, which must not change when the shelf price changes later.

## 5. Third Normal Form (3NF)

A table is in 3NF when it is in 2NF and no non-key attribute depends on another non-key attribute (no transitive dependency).

Functional dependencies of the final design:

| Table | Functional dependencies |
|---|---|
| CUSTOMERS | customer_id -> customer_name, phone, customer_type, created_at; phone -> customer_id |
| CATEGORIES | category_id -> category_name; category_name -> category_id |
| PRODUCTS | product_id -> product_name, category_id, current_price, quantity_in_stock, is_active, created_at |
| SALES | sale_id -> customer_id, sale_date, sale_status, cancelled_at, notes |
| SALE_ITEMS | sale_item_id -> sale_id, product_id, quantity, unit_price; (sale_id, product_id) -> sale_item_id |
| PAYMENTS | payment_id -> sale_id, amount, payment_method, payment_date, reference |
| INVENTORY_MOVEMENTS | movement_id -> product_id, sale_item_id, movement_type, quantity_change, movement_date, remarks |

In each table the determinant on the left is a candidate key (the surrogate key, or a UNIQUE column or pair), so there are no transitive dependencies and every table is also in BCNF.

The main 3NF decisions were `CUSTOMERS` and `CATEGORIES`.

- In `SALES`, `sale_id -> customer_id -> customer_name, phone, customer_type`. The customer facts depend on the customer, not on the sale, so they live in `CUSTOMERS`.
- If `PRODUCTS` stored `category_name` directly, then `product_id -> category_id -> category_name` would be a transitive dependency: renaming a category would mean updating every product in it. Moving the name into `CATEGORIES` fixes this.

**CATEGORIES**

| category_id | category_name |
|---:|---|
| 1 | Grains |
| 2 | Cooking Oil |
| 3 | Groceries |

**PRODUCTS**

| product_id | product_name | category_id |
|---:|---|---:|
| 1 | Rice 50kg | 1 |
| 2 | Beans 25kg | 1 |
| 3 | Vegetable Oil 5L | 2 |

Payments are separated from `SALES` so one sale can have several payments.

## 5.1 Deliberate Departures and Derived Values

| Item | What it is | Decision |
|---|---|---|
| `sale_items.unit_price` | Copy of the price at the time of sale | Kept on purpose. It is a different fact from `products.current_price`, so it is not redundancy. |
| `sale_items.line_total` | `quantity * unit_price` | Stored as a **generated column**: the database computes it, so it cannot disagree with its source. |
| Sale total and outstanding balance | Sum of line totals, minus payments | **Not stored.** Calculated by the view `v_sale_balances`, so it can never go stale. |
| `products.quantity_in_stock` | Equals the sum of `inventory_movements.quantity_change` | **Stored on purpose** (derived data). |

Strictly, `quantity_in_stock` breaks the "store each fact once" idea because it can drift away from the movement rows. It is kept because reading a product's stock is the most common operation at the till and should not need a scan of the history, and because a single row can be locked for Portfolio 3. The risk is controlled by changing the counter and its movement row in the same transaction, and `v_stock_reconciliation` shows any difference (it must be 0 for every product). The reasoning is in `03_design_notes.md`, section 3.

## 6. Benefits of Normalisation

The design provides the following benefits:

1. **Reduced duplication:** Category and customer details are stored separately from transaction records.
2. **Improved consistency:** Foreign keys prevent products from referencing nonexistent categories.
3. **Easier maintenance:** Category names and customer phone numbers can be updated in one place.
4. **Flexible transactions:** Sale items and payments can be recorded as separate rows.
5. **Historical accuracy:** Sale-item prices are preserved independently of current product prices.

## 7. Conclusion

The Adetwin Stores database uses normalisation principles to organise its data into related tables. Separating categories, products, customers, sales, sale items, payments, and inventory movements reduces unnecessary duplication and supports the store's operational requirements. The only stored derived value is the stock counter, which is a documented design decision and is checked by a reconciliation view.
