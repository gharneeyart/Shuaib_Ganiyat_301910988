# MIT 8103 Advanced Database Systems: Portfolio Documentation

**Student:** [full name, matric number]  **Case study:** Adetwin Stores POS and Inventory Management System
**GitHub repository:** https://github.com/gharneeyart/advanced-database-portfolio (private; the assessor has been given access)
**Databases:** PostgreSQL on Neon; MongoDB on Atlas

> Before submitting: delete this box; replace every `[ ... ]` with your own details or results; paste in the screenshots listed in section 4; check the document is 2 to 3 pages. Add the results of your own Neon and Atlas runs (see TESTING_GUIDE.md).

## 1. Selected Case Study

Adetwin Stores is a retail and wholesale business selling packaged foodstuff (rice, beans, oils, sugar, garri and similar goods). The database supports its point of sale and stock records, and is used consistently in all five portfolios.

| | |
|---|---|
| Users | Cashiers (record sales and payments), store managers (review sales and balances), inventory clerks (stock received and adjustments) |
| Major data | Customers, categories, products, sales (receipts), sale items, payments, inventory movements |
| Key operations | Record a sale with several items; take full or part payments (credit sales); calculate outstanding balances; update stock and keep a stock ledger; report on sales, collections and stock |

## 2. The Five Portfolio Activities

### Portfolio 1: Database design and modelling
I modelled seven tables (customers, categories, products, sales, sale_items, payments, inventory_movements) with primary keys, foreign keys and CHECK constraints (for example, prices and stock cannot be negative, a SALE movement must reference a sale item). The design is documented with an ER diagram, a relational schema and a normalisation walk-through from an unnormalised receipt to 3NF, with the functional dependencies of each table. Two stored values (`sales.total_amount` and `products.quantity_in_stock`) are derived from other rows; I kept them deliberately for fast reads and protect them with transactions. Every constraint was tested with failing and passing inserts (16 negative and 13 positive tests). One file, `seed.sql`, loads 30 products, 18 customers and 44 sales covering walk-in, fully paid, part-paid and unpaid cases, and `checks.sql` runs five integrity checks (sale totals, stock against the ledger, overpayment, credit sales without a customer, items without a stock movement) that must return no rows.

### Portfolio 2: Query processing and optimisation
Nine business queries (stock, sales, collections by payment method, outstanding balances, revenue per product) were run and analysed with `EXPLAIN ANALYZE`. I created indexes on product name and stock quantity and on the join columns (`payments.sale_id`, `sales.customer_id` and similar, which PostgreSQL does not index automatically), then compared the plans before and after. On this small data PostgreSQL kept using sequential scans, because the whole table fits in one page and reading it directly is cheaper than using an index. The lesson is that an index is not guaranteed to be used and should be judged from the plan and from data volume, not assumed; indexes also cost disk space and slow writes. [Add what my own Neon run showed.]

### Portfolio 3: Transactions and concurrency
Five PostgreSQL demonstrations: a complete sale (five tables) committed as one transaction and still present after reconnecting; a rollback, both deliberate and forced by the stock CHECK constraint, leaving no partial rows; and the problem of two cashiers selling the last bag of garri. With no control, both sessions read stock 1 and both sold it (two bags sold, one in stock). `SELECT ... FOR UPDATE` fixed this: the second session waits, then sees stock 0 and refuses. I also showed REPEATABLE READ keeping its snapshot (24) while another session sold a bag, then failing with a serialization error (SQLSTATE 40001) when updating the changed row, which the application must retry.

### Portfolio 4: NoSQL and advanced data models
I chose a document model in MongoDB Atlas, built with Mongoose. A `products` collection holds a flexible `attributes` object (rice has `weight_kg`, oil has `volume_litres`, noodles have `pieces`) and a `receipts` collection stores each receipt as one document with the customer, items and payments nested inside, because they are always read together; products are referred to by `product_id` because prices and stock change. Eight queries show filtering on flexible attributes, reading a whole receipt in one operation, aggregations (revenue per product, outstanding balances) and an atomic guarded stock decrement. Mongoose validation rejects invalid documents (negative price). With 30,000 extra receipts, `explain()` showed a collection scan reduced to an index scan examining only the matching documents. The costs are duplicated product names, no foreign keys, and validation done by the application, so stock and payments stay in PostgreSQL. [Add what my Atlas run showed.]

### Portfolio 5: Distributed and cloud database
I explain replication (primary and streaming replica), the availability versus consistency trade-off of asynchronous and synchronous replication (the CAP theorem), stale reads and the rule that stock checks go to the primary, manual and automatic failover and split brain, and sharding with a comparison of shard keys (a `customer_id` key creates a hot shard because walk-in sales have no customer). Sharding is not needed at Adetwin's size; the order of preference is indexes, a bigger server, read replicas, partitioning, then shards. Cloud evidence comes from Neon (version, encrypted connection, WAL settings, round-trip time) and from the three-node MongoDB Atlas replica set (members, `w:1` against `w:majority` write time, stale secondary reads). [Add my Neon and Atlas results.]

## 3. How the Work Was Tested

Every script was run, and the checklist with expected results is in `TESTING_GUIDE.md`. Results were checked rather than only displayed: the integrity checks catch a deliberately introduced error, MongoDB results were compared with the data by hand, and the concurrency demos were run as two real sessions. Limitations are written in each portfolio README (for example, replication and sharding are discussed rather than built, and the data are small).

## 4. Evidence (screenshots to include)

| Figure | Shows | File in the repository |
|---|---|---|
| 1 | Integrity checks returning no rows, and catching a deliberate error | `portfolio-1-database-design/evidence/` |
| 2 | A failing and a passing constraint test | `portfolio-1-database-design/evidence/` |
| 3 | Plan before and after an index | `portfolio-2-query-optimisation/evidence/` |
| 4 | Two-terminal lost update (two bags sold) and the `FOR UPDATE` fix | `portfolio-3-transactions-concurrency/evidence/` |
| 5 | REPEATABLE READ serialization error and retry | `portfolio-3-transactions-concurrency/evidence/` |
| 6 | Atlas collections and a receipt document; explain() before and after an index | `portfolio-4-nosql/evidence/` |
| 7 | Neon info and latency output, Neon console |  `portfolio-5-distributed-cloud/evidence/` |
| 8 | Atlas replica-set page and `atlas_cluster_info.txt` output | `portfolio-5-distributed-cloud/evidence/` |

## 5. Individual Technical Reflection

> Draft: rewrite in your own words and keep only what is true for you. The assessor values what you personally decided, found hard and learned.

The main design decision in Portfolio 1 was to store totals and stock as columns even though they can be calculated. That made reads simple but moved the responsibility for consistency into transactions, which is why Portfolio 3 matters to the design. The most useful result for me was the lost-update demonstration: the CHECK constraint did not catch the oversell, because the stale write set the stock to zero, a valid value, so the fix has to be in how the update is written (a lock or a guarded update). In Portfolio 2, the new indexes were ignored on a small table, which taught me to read the plan before assuming an index helps. In Portfolio 4 I learned to model from the reads: the receipt is one document because it is read as one thing, while products are separate because they change. In Portfolio 5 I learned that a poor shard key creates a hot shard even when the data looks evenly spread, and that availability and consistency pull in opposite directions. The hardest parts were [your own challenges, for example the two-session timing, connecting to Atlas, or understanding isolation levels]. If I continued, I would [for example add a branch column, automate failover, or synchronise PostgreSQL and MongoDB].

## 6. AI Use Declaration

- **Tool:** Claude Code (Anthropic), model Claude Sonnet 5.5.
- **Used for:** reviewing my portfolios against the brief; drafting and improving SQL scripts, test data, the MongoDB and Mongoose scripts, the concurrency demonstrations, and the READMEs and this document; explaining concepts.
- **How I checked it:** scripts were run on PostgreSQL and MongoDB and the real output saved; integrity checks and cross-database comparisons confirmed the data; [I re-ran all five portfolios on Neon and Atlas on (date), compared my results with the expected results, and corrected the figures in the documents]; I can explain each script. The full log is in `ai-use-log.md`.

## 7. References

- PostgreSQL Global Development Group. *PostgreSQL documentation* (transactions, explicit locking, `EXPLAIN`, high availability and replication, table partitioning). https://www.postgresql.org/docs/
- MongoDB, Inc. *MongoDB Manual* (data modelling, indexes, `explain`, replication, sharding). https://www.mongodb.com/docs/
- Mongoose. *Mongoose documentation* (schemas, validation, queries, aggregation). https://mongoosejs.com/docs/
- Neon. *Neon documentation*. https://neon.com/docs
- MongoDB Atlas. *Atlas documentation*. https://www.mongodb.com/docs/atlas/
- [Add the course textbook and lecture notes you used.]
