# Portfolio 1 – Database Design and Modelling

Case study: Adetwin Stores (see [Shuaib_Ganiyat_301910988_CASE_STUDY.md](Shuaib_Ganiyat_301910988_CASE_STUDY.md)).
Database: PostgreSQL (hosted on Neon).

## Contents
| File | Purpose |
|---|---|
| [Shuaib_Ganiyat_301910988_CASE_STUDY.md](Shuaib_Ganiyat_301910988_CASE_STUDY.md) | Organisation, users, data, operations, scope |
| [Shuaib_Ganiyat_301910988_ER_DIAGRAM.md](Shuaib_Ganiyat_301910988_ER_DIAGRAM.md) | ER diagram (Mermaid, crow's foot) |
| [Shuaib_Ganiyat_301910988_Database_Design.md](Shuaib_Ganiyat_301910988_Database_Design.md) | The seven tables, their keys and relationships |
| [Shuaib_Ganiyat_301910988_Normalisation.md](Shuaib_Ganiyat_301910988_Normalisation.md) | Normalisation to 3NF and where the design deliberately departs from it |
| [Shuaib_Ganiyat_301910988_ConstraintsTest.md](Shuaib_Ganiyat_301910988_ConstraintsTest.md) | Written record of the constraint tests |
| [Shuaib_Ganiyat_301910988_schema.sql](Shuaib_Ganiyat_301910988_schema.sql) | DDL: 7 tables, 1 partial unique index, 2 views |
| [Shuaib_Ganiyat_301910988_Seed.sql](Shuaib_Ganiyat_301910988_Seed.sql) | Small, hand-checkable data set (4 categories, 4 customers, 6 products, 2 sales, 4 sale lines, 2 payments, 10 stock movements) |
| [Shuaib_Ganiyat_301910988_ConstraintTests.sql](Shuaib_Ganiyat_301910988_ConstraintTests.sql) | Runnable constraint tests: 30 statements that must be rejected, 6 transaction blocks that must succeed (then roll back), 2 view checks |
| [evidence/](evidence/) | Screenshots of the constraint test output (`Shuaib_Ganiyat_301910988_Constraint_01.png` to `Shuaib_Ganiyat_301910988_Constraint_07.png`) |

## How to run
Use the **non-pooled** Neon connection string (the host has no `-pooler`). Put it in `.env` at the project root (see `.env.example`), **in double quotes**, because the URL contains `&`:

```bash
export DATABASE_URL="postgresql://USER:PASSWORD@HOST/DBNAME?sslmode=require"   
```

Then, from the project root:

```bash
source .env
echo "$DATABASE_URL"        

cd portfolio-1-database-design
psql "$DATABASE_URL" -f Shuaib_Ganiyat_301910988_schema.sql
psql "$DATABASE_URL" -f Shuaib_Ganiyat_301910988_Seed.sql
psql "$DATABASE_URL" -f Shuaib_Ganiyat_301910988_ConstraintTests.sql
psql "$DATABASE_URL" -c "SELECT * FROM v_stock_reconciliation;" -c "SELECT * FROM v_sale_balances;"
```

Run these in a terminal with `psql`. Pasting SQL directly into zsh does not work.

### Starting again
The schema file only has `CREATE` statements, so running it twice fails with "already exists". To reset the database first, run:

```bash
psql "$DATABASE_URL" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
```

then re-run the schema and seed files. Do this only on a database that holds nothing else you need.

### Running the test file
`Shuaib_Ganiyat_301910988_ConstraintTests.sql` starts with `\set ON_ERROR_STOP off`, so `psql` keeps going after each failed statement. Failed statements save nothing. Each positive block runs inside `BEGIN ... ROLLBACK`, and the view checks only read. The file can be re-run any number of times. Run it **right after the seed**: it uses fixed ids (for example category 1, sale 1), and failed inserts still use up identity values. The same statements, with the screenshots, are in [Shuaib_Ganiyat_301910988_ConstraintsTest.md](Shuaib_Ganiyat_301910988_ConstraintsTest.md).

## What was tested and how
The test file has seven sections. In each of sections 1 to 6, the **negative tests** must each print an ERROR that names the broken rule, and the **positive tests** (a `BEGIN ... ROLLBACK` block) must run without error. Section 7 checks the views.

| Section | Negative tests (must fail) | Positive tests (must succeed) |
|---|---|---|
| 1 Customers | customer type CHECK, UNIQUE phone, NOT NULL name (3) | customer with phone; several customers with no phone |
| 2 Categories, products | unique category, negative price, negative stock, category FK, category delete blocked (5) | zero price and stock; new category |
| 3 Sales | status CHECK, `ck_cancel_consistent` (twice), customer FK, sale delete blocked, customer delete blocked (6) | walk-in sale; sale for an existing customer |
| 4 Sale items | quantity CHECK, negative unit price, `uq_sale_product`, generated `line_total` not writable, product FK, sold product delete blocked (6) | a valid line with `line_total` calculated by the database |
| 5 Payments | amount CHECK, method CHECK, sale FK (3) | smallest amount; part payments by transfer and card |
| 6 Inventory movements | `ck_movement_sign` (twice), quantity zero, `ck_movement_link` (twice), `uq_one_sale_movement_per_item`, unknown type (7) | return after sale; restock |
| 7 Views | | `v_stock_reconciliation` shows no differences; sale 1 is fully paid |

That is **30 negative tests**, **6 positive blocks** and **2 view checks**.

Expected result: every negative statement prints an ERROR, the positive blocks print `INSERT 0 n` and `ROLLBACK` with no errors, the first view query returns 0 rows, and the second shows `outstanding = 0` for sale 1. Screenshots `Constraint_01` to `Constraint_07` (one per section) are in [evidence/](evidence/).

## Design decisions (summary; reasoning in [Shuaib_Ganiyat_301910988_Database_Design.md](Shuaib_Ganiyat_301910988_Database_Design.md) and [Shuaib_Ganiyat_301910988_Normalisation.md](Shuaib_Ganiyat_301910988_Normalisation.md))
1. Surrogate identity keys everywhere; natural keys kept as UNIQUE.
2. `ON DELETE RESTRICT` on all FKs: financial history must not vanish; sales are cancelled, not deleted.
3. `unit_price` is stored on each sale line (historical price snapshot, not redundancy).
4. Stock = counter on `products` plus an append-only `inventory_movements` ledger, kept consistent in one transaction and checked by `v_stock_reconciliation`.
5. Outstanding balances are computed in a view (`v_sale_balances`), not stored, so they cannot go stale.
