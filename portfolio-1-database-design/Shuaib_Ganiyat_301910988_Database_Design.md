# Portfolio 1 – Database Design and Modelling

> The case study statement is in [Shuaib_Ganiyat_301910988_CASE_STUDY.md](Shuaib_Ganiyat_301910988_CASE_STUDY.md).

## 1. Relational design

| Table | Primary key | Other keys / constraints |
|---|---|---|
| customers | customer_id | UNIQUE(phone); CHECK customer_type IN (retail, wholesale) |
| categories | category_id | UNIQUE(category_name) |
| products | product_id | FK category_id; CHECK price >= 0 and stock >= 0 |
| sales | sale_id | FK customer_id (nullable = walk-in); CHECK status/cancelled_at consistent |
| sale_items | sale_item_id | FK sale_id, product_id; UNIQUE(sale_id, product_id); CHECK quantity > 0 and unit_price >= 0; `line_total` is generated (quantity × unit_price) |
| payments | payment_id | FK sale_id; CHECK amount > 0; CHECK method in (cash, transfer, card) |
| inventory_movements | movement_id | FK product_id, sale_item_id (nullable); sign and link CHECKs; partial UNIQUE on sale movements |

**Surrogate keys** (identity columns) are used everywhere because natural candidates (names, phones) can change or be absent. Natural candidate keys are still enforced with UNIQUE where they exist.

**Delete rules.** Every foreign key is `ON DELETE RESTRICT`. A shop's sales, payments and stock history are financial records, so deleting a parent must never silently erase children. A sale is withdrawn by setting `sale_status = 'cancelled'` (with `cancelled_at`), not by deleting it.

**Why `sale_items` has both a surrogate PK and `UNIQUE(sale_id, product_id)`.** The surrogate gives movements a simple single-column FK target. The UNIQUE encodes a business rule: one line per product per sale (the cashier raises the quantity rather than adding a duplicate line).

## 2. Normalisation
See [Shuaib_Ganiyat_301910988_Normalisation.md](Shuaib_Ganiyat_301910988_Normalisation.md): unnormalised receipt and its anomalies, 1NF, 2NF, 3NF/BCNF with functional dependencies, and the deliberate departures (price snapshot, generated `line_total`, stock counter).

## 3. Stock design decision (counter + ledger)
Two representations of stock exist:
- `products.quantity_in_stock`, a counter that is cheap to read and to lock.
- `inventory_movements`, an append-only ledger giving history and audit.

**Decision:** the counter is the operational source of truth and the ledger is the audit trail. Both are changed in the **same transaction** (demonstrated in Portfolio 3). Drift is detectable at any time with `SELECT * FROM v_stock_reconciliation;`, where `difference` must be 0 for every product. The seed data starts reconciled (opening movements + sales = current stock).

Trade-off: storing derived data risks drift; computing from the ledger alone would be normalised but slower for every stock check and impossible to lock as a single row.

## 4. Business rules: where each is enforced

| Rule | Enforced by |
|---|---|
| Positive quantities, prices >= 0, payments > 0, stock >= 0 | CHECK constraints |
| Valid customer type / payment method / sale status / movement type | CHECK constraints |
| No orphan rows; history cannot be deleted | FKs with ON DELETE RESTRICT |
| Cancelled status and cancelled_at agree | `ck_cancel_consistent` |
| Sale movement is negative; opening/restock/return positive | `ck_movement_sign` |
| Sale/return movement must reference its sale line; others must not | `ck_movement_link` |
| One sale movement per sale line, but a later return may reference it too | partial unique index `uq_one_sale_movement_per_item` |
| One line per product per sale | `uq_sale_product` |
| Outstanding balance of a credit sale | view `v_sale_balances` (not stored, so it cannot go stale) |
| Counter and ledger agree | same-transaction updates + `v_stock_reconciliation` |
| Payments must not exceed the sale total | **Not in the schema** (needs a cross-table check). Detected by `v_sale_balances` where `outstanding < 0`; to be prevented in the sale/payment transaction |
| A credit (unpaid or part-paid) sale must have a customer | **Not in the schema.** "Credit" is not a stored flag: it is any sale whose `outstanding` is above 0 in `v_sale_balances`, and `sales.customer_id` is nullable for walk-ins. Enforced by the application; detectable with `SELECT * FROM v_sale_balances WHERE customer_id IS NULL AND outstanding > 0` |
| A cancelled sale restores stock and stops accepting payments | **Application/transaction rule**, not in the schema. Restoring stock is a `return` movement per line |

## 5. Limitations
Overpayment and cancellation side effects are transaction-level rules, not declarative constraints; a trigger could enforce them but was avoided so the transaction steps stay visible for Portfolio 3. No customer-specific wholesale price tiers are modelled (one `current_price`).

## 6. ER diagram
See [Shuaib_Ganiyat_301910988_ER_DIAGRAM.md](Shuaib_Ganiyat_301910988_ER_DIAGRAM.md) (Mermaid; renders on GitHub). 

## 7. How to rebuild and verify
Load the connection string first (`source .env`; the URL must be in double quotes because it contains `&`), then from this folder:

```bash
psql "$DATABASE_URL" -f Shuaib_Ganiyat_301910988_schema.sql
psql "$DATABASE_URL" -f Shuaib_Ganiyat_301910988_seed.sql
psql "$DATABASE_URL" -c "SELECT * FROM v_stock_reconciliation;" -c "SELECT * FROM v_sale_balances;"
```
The schema file has no `DROP` statements, so to rebuild on a database that already has the tables, first run `DROP SCHEMA public CASCADE; CREATE SCHEMA public;` (this erases everything in that database).

With the seed data, `v_stock_reconciliation` shows `difference = 0` for all six products. In `v_sale_balances`, sale 1 is fully paid (34,500) and sale 2 has 112,000 outstanding (total 212,000, paid 100,000).

The full test run is `Shuaib_Ganiyat_301910988_ConstraintTests.sql` (36 tests; see [Shuaib_Ganiyat_301910988_README.md](Shuaib_Ganiyat_301910988_README.md)). Three examples that must fail: `DELETE FROM sales WHERE sale_id = 1;` (RESTRICT), a `sale` movement with a positive quantity (`ck_movement_sign`), and a second `sale` movement for the same sale item (`uq_one_sale_movement_per_item`).
