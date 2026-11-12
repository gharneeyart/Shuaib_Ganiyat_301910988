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
The test file starts with `\set ON_ERROR_STOP off`, so `psql` keeps going after each failed statement. Part A statements fail, so they save nothing. Part B runs in a transaction that ends with `ROLLBACK`. Part C only reads. The test file can be re-run any number of times. Run it **right after the seed**: it uses fixed IDs (for example category 1, sale 1), and failed inserts still use up identity values.

## What was tested and how
`Shuaib_Ganiyat_301910988_ConstraintTests.sql` is a plain list of SQL statements, each with a comment saying which rule it tests. Part A (tests 1-29) must each print an ERROR that names the broken rule. Part B (30-34) must be accepted. Part C (35-36) checks the views.

| Tests | What they prove |
|---|---|
| 1–3 | customer type CHECK, UNIQUE phone, NOT NULL name |
| 4–8 | unique category, price/stock CHECKs, product FK, category delete blocked |
| 9–14 | sale status CHECK, `ck_cancel_consistent`, customer FK, delete of a sale/customer blocked |
| 15–19 | quantity CHECK, `uq_sale_product`, generated `line_total` not writable, product FK, sold product cannot be deleted |
| 20–22 | payment amount/method CHECKs, sale FK |
| 23–29 | `ck_movement_sign`, `ck_movement_link`, `uq_one_sale_movement_per_item`, movement type CHECK |
| 30–34 | must succeed: several NULL phones, walk-in sale, second payment, return after sale, restock |
| 35–36 | derived views agree with the seed data (no stock difference; sale 1 fully paid) |

Expected result: Part A prints an ERROR for every statement, Part B prints no errors, test 35 returns no rows, and test 36 shows `outstanding = 0` for sale 1. Screenshots of the output are saved in [evidence/](evidence/).

## Design decisions (summary; reasoning in [Shuaib_Ganiyat_301910988_Database_Design.md](Shuaib_Ganiyat_301910988_Database_Design.md) and [Shuaib_Ganiyat_301910988_Normalisation.md](Shuaib_Ganiyat_301910988_Normalisation.md))
1. Surrogate identity keys everywhere; natural keys kept as UNIQUE.
2. `ON DELETE RESTRICT` on all FKs: financial history must not vanish; sales are cancelled, not deleted.
3. `unit_price` is stored on each sale line (historical price snapshot, not redundancy).
4. Stock = counter on `products` plus an append-only `inventory_movements` ledger, kept consistent in one transaction and checked by `v_stock_reconciliation`.
5. Outstanding balances are computed in a view (`v_sale_balances`), not stored, so they cannot go stale.
