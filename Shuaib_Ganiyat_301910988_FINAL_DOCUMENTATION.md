# MIT 8103 Advanced Database Systems: Final Documentation

**Full Name:** Ganiyat Shuaib
**StudentID:** 301910988  
**Matric No.:** 2026/A/MIT/0385
**Miva Email Address:** g.shuaib0988@miva.edu.ng
**Case study:** Adetwin Stores POS and Inventory Management System
**GitHub repository:** [https://github.com/gharneeyart/Shuaib_Ganiyat_301910988](https://github.com/gharneeyart/Shuaib_Ganiyat_301910988)
**Databases:** PostgreSQL 18 on Neon; MongoDB 8.0 on Atlas

## 1. Selected Case Study

Adetwin Stores is a retail and wholesale business that sells packaged foodstuff and household goods (rice, beans, cooking oil, tomato paste, beverages, laundry soap, and similar items). The database supports its point-of-sale and stock records, and all five portfolios use the same case study.

| | |
|---|---|
| Users | Cashiers (record sales and payments), store managers (review sales and balances), inventory clerks (stock received and adjustments) |
| Major data | Customers, categories, products, sales (receipts), sale items, payments, inventory movements |
| Key operations | Record a sale with several items; take full or part payments (credit sales); calculate outstanding balances; update stock and keep a stock ledger; report on sales, collections and stock |

## 2. The Five Portfolio Activities

### Portfolio 1: Database design and modelling
I modelled seven tables (customers, categories, products, sales, sale_items, payments, inventory_movements) with primary keys, foreign keys (all `ON DELETE RESTRICT`) and CHECK constraints; for example, prices and stock cannot be negative, and a `sale` stock movement must be negative and must reference a sale line. The design includes an ER diagram, the relational schema, and a normalisation walk-through from an unnormalised receipt to 3NF/BCNF, with the functional dependencies of each table. I kept three things on purpose and explained each one: the price copied onto each sale line (`unit_price`, a historical snapshot), `line_total` as a generated column, and the stock counter on `products`, which is derived from the movement ledger. Outstanding balances are not stored; they come from the view `v_sale_balances`, and `v_stock_reconciliation` shows any drift between counter and ledger. Every constraint was tested: 30 statements that must be rejected, 6 transaction blocks that must succeed and then roll back, and 2 view checks, with 7 screenshots.

### Portfolio 2: Query processing and optimisation
I loaded about 200,000 sales (about 500,000 sale lines) so that plans would be meaningful, wrote eight business queries (credit exposure, reorder list, daily revenue, top customers, best products per category, customers who never bought, stock history, sales of one product) and ran five index experiments with `EXPLAIN (ANALYZE, BUFFERS)` before and after. The composite index on `inventory_movements(product_id, movement_date DESC)` made Q7 about 400 times faster (31.7 ms to 0.079 ms, 4,907 pages to 23). An index on the foreign key `sale_items.product_id` made Q8 about 48 times faster (32.0 to 0.673 ms). Three other indexes helped little (about 1.4x to 1.5x). The date index on `sales` was meant not to help: it replaced a filter but the pages read did not fall (6,339 to 6,364), because the expensive part is scanning `sale_items`. The lesson is to read the plan and the buffer counts, not only the time, and that every index costs disk space and slows writes.

### Portfolio 3: Transactions and concurrency
Eight PostgreSQL demonstrations on Neon: a restock committed as one transaction and a second one rolled back (counter and ledger stay equal); `record_sale()`, an atomic sale across `sales`, `sale_items`, `payments`, `inventory_movements` and `products`; a failing sale (9,999 units requested) that leaves no rows behind; READ COMMITTED showing a non-repeatable read (25 then 24); and REPEATABLE READ keeping its snapshot (23, 23) and then failing with `could not serialize access due to concurrent update` (SQLSTATE 40001) when it tried to update a row another session had changed, which the application must retry. The concurrency problem is two customers buying the last unit of a product. With no control, both sessions read stock 1 and both sold it (two sales, final stock 0). `SELECT ... FOR UPDATE` fixed it: the second session waited, then read 0 and did not sell.

### Portfolio 4: NoSQL and advanced data models
I chose a document model in MongoDB Atlas and ran it with `mongosh`. A `products` collection holds a flexible `attributes` object (rice has `grainType`, oil has `volumeLitres`, malt has `bottlesPerPack`); a `sales` collection stores each receipt as one document with the customer snapshot, items and payments embedded, because they are always read together; stock movements are a separate `inventoryEvents` collection because they grow without limit. The scripts show reads on flexible and nested fields, updates, an atomic guarded stock decrement, five aggregations (sales by payment status, amount paid and outstanding, revenue per product, stored total against items, counter against ledger) and JSON Schema validators. With 20,000 synthetic events, `explain("executionStats")` showed a `COLLSCAN` examining 20,011 documents (16 ms) replaced by an `IXSCAN` examining 20 (1 ms) after a compound index. Ten validation tests pass, including the one that shows MongoDB has no foreign keys: a sale for a product that does not exist is accepted. The costs are duplicated names, no foreign keys, and redundant totals; stock and payments stay in PostgreSQL, and the two databases are not synchronised.

### Portfolio 5: Distributed and cloud database
The design discussion explains replication, which reads must go to the primary (stock checks and balances) and which may use a replica (catalogue and reports), consistency across two databases with an outbox pattern as the proposal, failure scenarios, and sharding with a comparison of shard keys (`(store_id, sale_date)` proposed), plus a partitioning sketch. A single store does not need sharding. Cloud evidence comes from two scripts: Neon (PostgreSQL 18.6, encrypted TLS 1.3 connection, writable primary with no replica, 8,648 kB database, compute suspended when idle and restarted later) and the three-node Atlas replica set (members, 50 inserts each with `w:1` at 149 ms and `w:majority` at 132 ms, which is within network noise, and a read served by a secondary). Replication, failover, backups, and sharding were not built or tested; section 7 and 8 of the architecture document list what is implemented and what is only proposed.

## 3. How the Work Was Tested

Every script was run by me against Neon and Atlas, and the output was saved as screenshots or text in the `evidence/` folder of each portfolio. Results were checked, not only displayed: the constraint tests show the exact rule named in each error, the reconciliation view returns no differences after every transaction demo, the MongoDB aggregations were compared with the seed data by hand, and the concurrency demos were run as two real `psql` sessions side by side. A final pass compared every number in the READMEs with the screenshots and fixed the differences. Known limits are written in the READMEs: the data are small except in Portfolio 2, replication and sharding are discussed rather than built, and the Atlas free tier has no backups.

## 4. Evidence

| Figure | Shows | Files in the repository |
|---|---|---|
| 1 | Constraint tests, sections 1 to 7: each failing statement names its rule, positive blocks roll back, views agree | `portfolio-1-database-design/evidence/Shuaib_Ganiyat_301910988_Constraint_01.png` to `_07.png` |
| 2 | Plan before and after each of the five indexes, and the output of the eight queries | `portfolio-2-query-optimisation/evidence/Shuaib_Ganiyat_301910988_Index_Exp1_before.png` to `Exp5_after.png`, `…_Q1_Q8_result.txt` |
| 3 | Commit, rollback, atomic sale and failed sale | `portfolio-3-transactions-concurrency/evidence/Shuaib_Ganiyat_301910988_01_…` to `_03_…` |
| 4 | Two-terminal lost update (two sales of one unit) and the `FOR UPDATE` fix | `…_08_lost_update_session.png`, `…_09_for_update_session.png` in the same folder |
| 5 | READ COMMITTED, REPEATABLE READ and the serialization error | `…_04_…`, `…_05_…`, `…_06_…` in the same folder |
| 6 | Atlas documents and validator, queries, updates, aggregations, explain before and after an index, validation tests | `portfolio-4-nosql/evidence/Shuaib_Ganiyat_301910988_01-seed.png` to `…_04-validation.png` |
| 7 | Neon version, TLS and cold start; Neon compute and restore pages | `portfolio-5-distributed-cloud/evidence/…_neon_checks.png`, `_neon_checks_2.png`, `_neon_cold_start.png`, `_neon_compute.png`, `_neon_restore.png` |
| 8 | Atlas replica set output and cluster page | `portfolio-5-distributed-cloud/evidence/…_atlas_replica_check.png`, `_atlas_cluster.png` |

## 5. Individual Technical Reflection

For me, the biggest part of this project was having to learn SQL properly. I started on db-fiddle, where I could try a query in the browser. Then I moved to running PostgreSQL on my own machine, and finally to Neon, a cloud PostgreSQL database that I connect to from the terminal with `psql`. Each step taught me something new. Locally, I learned how a database actually runs and how to load scripts. On Neon, I learned about connection strings, TLS, and that the database suspends when idle and has to wake up again.

My highlight was learning SQL commands I had never used, especially `RETURNING`. In `record_sale()` and in the concurrency demos, I used it to get back the `sale_id` of a row I had just inserted, so the sale lines and payment could be linked to it without a second query. It also taught me how one statement can insert a row and pass its ID straight to the next step.

This was also my first time using `mongosh`. I only knew MongoDB through Mongoose in Node.js, where a schema in application code does the validating. In `mongosh` there is no Mongoose, so I put the rules in the database itself with JSON Schema validators and unique indexes, and I saw directly how MongoDB behaves: it rejected bad documents but accepted a sale for a product that does not exist, because it has no foreign keys.

The technical results that stayed with me:
- **Portfolio 1:** I kept a stock counter on `products` even though it can be calculated from the movement ledger. Reads are fast, and there is one row to lock, but keeping it correct became the job of transactions, which is why Portfolio 3 matters to the design.
- **Portfolio 2:** Three of the five indexes helped very little, and the date index did not reduce the pages read at all. I learned to read the buffer counts in the plan, not just the time.
- **Portfolio 3:** The lost-update demo showed that the CHECK `quantity_in_stock >= 0` did not stop an oversell, because the stale write set the stock to 0, which is a valid value. The fix is in how the update is written: a lock with `SELECT ... FOR UPDATE`.
- **Portfolio 4:** I modelled MongoDB from the reads. A sale is one document because it is read as one thing, and stock events are separate because they grow forever.
- **Portfolio 5:** Availability and consistency pull in opposite directions, and sharding is a proposal here, not something this small shop needs.

The hardest parts were practical. Connection strings were silently empty, so `psql` and `mongosh` fell back to localhost. A `&` in the URL cut the line in `.env`. The concurrency demos needed two terminals timed carefully. If I continued, I would add a branch column, build the outbox between PostgreSQL and MongoDB, and test a failover.

## 6. AI Use Declaration

- **Tool:** Claude Code (Anthropic), model Claude Sonnet 5.5.
- **Used for:** Generating the bulk data file, revising the READMEs and this document after my files were renamed, explaining connection and tooling errors, scanning the repository for mismatches between documents, scripts, and screenshots, and recreating the Portfolio 1 constraint test file from my written test record.
- **How I checked it:** I ran every database script myself on Neon and Atlas and saved the real output; the tool did not run my scripts. I compared the changed documents with that output and with my screenshots. 

## 7. References

- PostgreSQL Global Development Group. *PostgreSQL documentation* (transactions, explicit locking, `EXPLAIN`, high availability and replication, table partitioning). https://www.postgresql.org/docs/
- MongoDB, Inc. *MongoDB Manual* (data modelling, indexes, `explain`, replication, sharding). https://www.mongodb.com/docs/
- MongoDB, Inc. *mongosh documentation*. https://www.mongodb.com/docs/mongodb-shell/
- Neon. *Neon documentation*. https://neon.com/docs
- MongoDB Atlas. *Atlas documentation*. https://www.mongodb.com/docs/atlas/
- Course textbook and lecture notes for MIT 8103.
