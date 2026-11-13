# Portfolio 2 – Query Processing and Optimisation

Case study: Adetwin Stores (see [CASE_STUDY](../portfolio-1-database-design/Shuaib_Ganiyat_301910988_CASE_STUDY.md)). Database: PostgreSQL on Neon. This portfolio uses the Portfolio 1 schema, so load that first.

## Files
| File | Purpose |
|---|---|
| [sql/Shuaib_Ganiyat_301910988_bulk_data.sql](sql/Shuaib_Ganiyat_301910988_bulk_data.sql) | Generates about 200k sales (about 500k sale lines) with `generate_series`, so plans are meaningful. The 6-product seed data is too small for PostgreSQL to ever choose an index. |
| [sql/Shuaib_Ganiyat_301910988_business_queries.sql](sql/Shuaib_Ganiyat_301910988_business_queries.sql) | The eight business queries Q1 to Q8, each with its business question. The commented-out block at the top is an older query set that no longer matches the schema. |
| [sql/Shuaib_Ganiyat_301910988_execution_plans.sql](sql/Shuaib_Ganiyat_301910988_execution_plans.sql) | Five index experiments (`CREATE INDEX` plus `ANALYZE`), run one block at a time with `EXPLAIN (ANALYZE, BUFFERS)` before and after. |
| [evidence/](evidence/) | `Shuaib_Ganiyat_301910988_Q1_Q8_result.txt` (output of the eight queries) and the before/after plan screenshots `Shuaib_Ganiyat_301910988_Index_Exp1_before.png` to `..._Exp5_after.png`. |

## How to run
Load the connection string first. `.env` is in the project root, so from this folder use `source ../.env` (a new terminal needs this again), then check that it printed a URL:

```bash
source ../.env
echo "$DATABASE_URL"

# 1. Portfolio 1 schema and seed must already be loaded (see ../portfolio-1-database-design/Shuaib_Ganiyat_301910988_README.md)
# 2. Load the bulk data (add -v sales_n=50000 for a smaller database)
psql "$DATABASE_URL" -f sql/Shuaib_Ganiyat_301910988_bulk_data.sql

# 3. Run the eight queries and keep the output
psql "$DATABASE_URL" -f sql/Shuaib_Ganiyat_301910988_business_queries.sql > evidence/Shuaib_Ganiyat_301910988_Q1_Q8_result.txt 2>&1

# 4. Experiments: for each one, run the query with EXPLAIN (ANALYZE, BUFFERS) in front,
#    run its CREATE INDEX + ANALYZE from sql/Shuaib_Ganiyat_301910988_execution_plans.sql, then EXPLAIN again.
```
Tip: `sql/Shuaib_Ganiyat_301910988_execution_plans.sql` contains the `CREATE INDEX` statements and commented placeholders for the `EXPLAIN` runs. Copy one experiment at a time into `psql` rather than running the whole file, so you can capture each "before" plan first.

## Queries
| Query | Business question | Technique |
|---|---|---|
| Q1 | Which customers owe the most? | CTEs, LEFT JOIN, GROUP BY, HAVING |
| Q2 | Which active products need restocking (<= 15)? | filter |
| Q3 | Daily revenue for June | date range, join, aggregate (returns 31 rows, see the note below) |
| Q4 | Top 10 customers by purchases | 3-table join, aggregate |
| Q5 | Best 3 products per category | window function (`ROW_NUMBER`) |
| Q6 | Customers who never bought | `NOT EXISTS` anti-join |
| Q7 | Last 20 stock movements of a product | equality + ORDER BY + LIMIT |
| Q8 | Sales lines of one product | selective filter on an FK column |

**Q3 time zone note.** The date range is written in Lagos time (`+01`), but the Neon session time zone is UTC, so `date_trunc('day', ...)` puts sales made between 00:00 and 01:00 on 1 June into the row labelled `2026-05-31` (23 sales). That is why Q3 returns 31 rows instead of 30. The query was left unchanged so it matches the saved plans in the Exp5 screenshots.

## Results
Environment: PostgreSQL 18 (the plan output format with `Index Searches` is PostgreSQL 18), hosted on Neon, rows in `sales` 200,002, `sale_items` 499,401, `inventory_movements` about 516,000, `products` 2,006, `customers` 20,004.
Timing method: execution time from `EXPLAIN (ANALYZE, BUFFERS)`, middle of 3 runs.

| # | Index | Query | Plan before | Time before (ms) | Plan after | Time after (ms) | Evidence file |
|---|---|---|---|---|---|---|---|
| 1 | `idx_inventory_product_date` (composite) | Q7 | Parallel Seq Scan + top-N sort; scanned about 516,000 rows to keep about 4,500; Buffers `hit=4907` | 31.7 (runs: 286.4 cold, 31.7, 29.8) | Index Scan using `idx_inventory_product_date`; no sort; reads 20 rows; Buffers `hit=23` | 0.079 (runs: 0.097, 0.079, 0.079) | `evidence/Shuaib_Ganiyat_301910988_Index_Exp1_before.png`, `evidence/Shuaib_Ganiyat_301910988_Index_Exp1_after.png` |
| 2 | `idx_sale_items_product_id` (single, FK) | Q8 | Parallel Seq Scan on `sale_items` (about 500,000 rows read, about 166,000 per worker discarded) + Nested Loop to `sales_pkey` + top-N sort; Buffers `hit=5362` | 32.0 (runs: 311.1 cold, 32.0, 28.8) | Bitmap Index Scan on `idx_sale_items_product_id` + Bitmap Heap Scan (169 rows) + Nested Loop to `sales_pkey` + top-N sort; Buffers `hit=841` | 0.673 (runs: 0.732, 0.669, 0.673) | `evidence/Shuaib_Ganiyat_301910988_Index_Exp2_before.png`, `evidence/Shuaib_Ganiyat_301910988_Index_Exp2_after.png` |
| 3 | `idx_sales_customer_id` (single, FK) | Q6 | Hash Right Anti Join: Seq Scan on `sales` (200,002 rows) hashed against Seq Scan on `customers`; Buffers `hit=1845` | 35.8 (runs: 223.2 cold, 35.8, 34.9) | Merge Anti Join: Index Scan on `customers_pkey` + Index Only Scan on `idx_sales_customer_id` (Heap Fetches 0); Buffers `hit=459` | 25.4 (runs: 28.8, 25.4, 24.7) | `evidence/Shuaib_Ganiyat_301910988_Index_Exp3_before.png`, `evidence/Shuaib_Ganiyat_301910988_Index_Exp3_after.png` |
| 4 | `idx_products_low_stock` (partial) | Q2 | Seq Scan on `products` (2,006 rows, 1,866 discarded) + sort; Buffers `hit=45` | 0.202 (runs: 7.8 cold, 0.202, 0.197) | Bitmap Index Scan on `idx_products_low_stock` + Bitmap Heap Scan (140 rows) + sort; Buffers `hit=26` | 0.134 (runs: 0.134, 0.139, 0.132) | `evidence/Shuaib_Ganiyat_301910988_Index_Exp4_before.png`, `evidence/Shuaib_Ganiyat_301910988_Index_Exp4_after.png` |
| 5 | `idx_sales_sale_date` (may not help) | Q3 | Parallel Hash Join: Parallel Seq Scan on `sale_items` (4,668 pages) + Parallel Seq Scan on `sales` with date filter (1,639 pages); Buffers `hit=6339` | 156.8 (runs: 484.8 cold, 156.8, 144.9) | Hash Join: Bitmap Index Scan on `idx_sales_sale_date` (57 pages) + Bitmap Heap Scan on `sales` (still 1,639 heap blocks), Seq Scan on `sale_items` unchanged; no parallel workers; Buffers `hit=6364` | 111.1 (runs: 111.1, 107.4, 111.1) | `evidence/Shuaib_Ganiyat_301910988_Index_Exp5_before.png`, `evidence/Shuaib_Ganiyat_301910988_Index_Exp5_after.png` |

## Performance analysis

### Summary

| # | Index | Query | Before (ms) | After (ms) | Faster by | Pages read (before -> after) |
|---|---|---|---:|---:|---:|---|
| 1 | `idx_inventory_product_date` | Q7 | 31.7 | 0.079 | about 400x | 4,907 -> 23 |
| 2 | `idx_sale_items_product_id` | Q8 | 32.0 | 0.673 | about 48x | 5,362 -> 841 |
| 3 | `idx_sales_customer_id` | Q6 | 35.8 | 25.4 | about 1.4x | 1,845 -> 459 |
| 4 | `idx_products_low_stock` | Q2 | 0.202 | 0.134 | about 1.5x | 45 -> 26 |
| 5 | `idx_sales_sale_date` | Q3 | 156.8 | 111.1 | about 1.4x | 6,339 -> 6,364 |

### Plans before and after
- **Q7 (index 1):** before, a Parallel Seq Scan read the whole `inventory_movements` table (about 516,000 rows) and a top-N sort picked the newest 20 of about 4,500 matches. After, a plain Index Scan on `idx_inventory_product_date` reads 20 entries and no sort is needed.
- **Q8 (index 2):** before, a Parallel Seq Scan on `sale_items` threw away about 166,000 rows per worker to find 169, then a Nested Loop looked each one up in `sales_pkey`. After, a Bitmap Index Scan finds the 169 rows and a Bitmap Heap Scan reads them. The Nested Loop and sort remain.
- **Q6 (index 3):** before, a Hash Right Anti Join with a Seq Scan on all of `sales`. After, a Merge Anti Join with an Index Only Scan on `idx_sales_customer_id` (Heap Fetches: 0) merged against `customers_pkey`.
- **Q2 (index 4):** before, a Seq Scan on `products` followed by a sort. After, a Bitmap Index Scan on the partial index and a Bitmap Heap Scan, still followed by a sort.
- **Q3 (index 5):** before, a Parallel Hash Join with Parallel Seq Scans on both tables. After, a Hash Join where `sales` is read through a Bitmap Index Scan on `idx_sales_sale_date`; `sale_items` is still a Seq Scan and the plan no longer uses parallel workers.

### Which index helped most, and why
Index 1 (`idx_inventory_product_date`) gave the biggest improvement, about 400 times faster. Without it, PostgreSQL had to read every one of about 516,000 rows to find the movements of one product, then sort about 4,500 of them to keep 20. The composite index is sorted by `product_id` and then by `movement_date` newest first, so PostgreSQL jumps straight to product 7 and reads the first 20 entries, already in the order the query asks for. That avoids the table scan, the filter, the sort and the parallel workers, and the `LIMIT 20` lets it stop after 20 rows. The pages read fell from 4,907 to 23.

Index 2 (`idx_sale_items_product_id`) was second, about 48 times faster. It is an index on a foreign-key column. PostgreSQL does not create an index for a foreign key automatically, so `sale_items.product_id` was not indexed until this experiment. The index finds the 169 matching rows directly instead of scanning about 500,000. It uses a bitmap scan because 169 rows are scattered through the table.

### Indexes that gave little benefit
- **Index 3 (Q6, about 1.4x).** The query asks for customers with no sales, and only 9 exist, which is fewer than `LIMIT 20`, so the query cannot stop early. PostgreSQL has to compare every customer with every `customer_id` in `sales` (the Index Only Scan returned 160,303 entries). The index did not let it skip anything. It only made the thing it reads smaller: pages read fell from 1,845 to 459 because the index holds just `customer_id`, and the hash join became a merge join.
- **Index 4 (Q2, about 1.5x).** `products` has only 2,006 rows in 45 pages, so scanning it is already cheap (0.2 ms). The query returns 140 rows, about 7% of the table. The gain is real but tiny in absolute terms. The index is partial, so it only holds the rows with `is_active` and 15 units or fewer.
- **Index 5 (Q3, about 1.4x, and the one meant not to help).** The buffer counts show that the index did not reduce the work: 6,339 pages before and 6,364 after. June is about 10% of the sales (about 19,800 of 200,002), but those rows are spread over the whole table, because sales are stored in `sale_id` order while the dates are random. The Bitmap Heap Scan therefore still had to read all 1,639 pages of `sales` (`Heap Blocks: exact=1639`); the index only replaced the filter with 57 index pages. The expensive part of this query is the scan of `sale_items` (4,668 pages, about 500,000 rows), because every item of every June sale must be summed, and no index on `sales` can change that. The plan also stopped using parallel workers, so I do not claim that the 30% saving came from the index alone.

### Why `product_id` comes before `movement_date` in the composite index
The query filters on `product_id` with `=` and sorts by `movement_date`. An index is sorted by its first column, then by the second inside each first-column value. With `product_id` first, all rows for one product sit together and are already ordered by date, so PostgreSQL can jump to product 7 and read the newest 20. With `(movement_date, product_id)` the entries would be sorted by date first and product 7's rows would be scattered through the whole index, so it could not jump straight to them.

### The cost of an index
- **Disk space:** every index is an extra copy of the indexed columns. I did not measure the sizes in this experiment. You can see them with `SELECT pg_size_pretty(pg_relation_size('idx_inventory_product_date'));`.
- **Slower writes:** every INSERT, DELETE, or UPDATE of an indexed column must also update each index. `inventory_movements` and `sale_items` are written on every sale, so their indexes add work to the till.
- **Maintenance:** more indexes mean more for VACUUM and the planner to deal with. An index that does not help, such as `idx_sales_sale_date`, costs this without giving anything back, so it should be dropped.
- **Redundant indexes:** `sale_items(sale_id)` was deliberately not created, because the unique constraint `uq_sale_product (sale_id, product_id)` already provides an index that starts with `sale_id`.

### Method note
Each time is the middle of three runs. The first run of every "before" was far slower (for example 286 ms against 31.7 ms for Q7) because the data had to be read from disk (`read=...` in Buffers), so it was not used. Results come from one Neon database and will vary a little with caching and load.

## Reading a plan (short reference)
- **Seq Scan**: reads the whole table. **Index Scan**: follows a B-tree to matching rows. **Bitmap Heap Scan**: collects matching row locations first, then reads the pages in order.
- **Hash Join / Merge Join / Nested Loop**: three ways to join two row sets.
- `cost=` is the planner's estimate; `actual time=` and `rows=` are measured; `Buffers: shared hit=N` is the number of 8 kB pages touched.
