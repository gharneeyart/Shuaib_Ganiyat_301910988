# Portfolio 3 – Transactions and Concurrency

Case study: Adetwin Stores. The scenario throughout is the one a shop really faces: **two customers buy the last unit of a product at the same moment**, and a sale touches several tables that must stay consistent.

## Files
All SQL files are in [sql/](sql/) and are prefixed `Shuaib_Ganiyat_301910988_`. The prefix is left out of the table below to keep it readable.

| File (in `sql/`) | Shows |
|---|---|
| `01_commit_rollback.sql` | COMMIT and ROLLBACK of a restock that changes two tables (counter + ledger) |
| `02_sale_transaction.sql` | `record_sale()`: one atomic sale (lock, check, 4 inserts, 1 update); successful runs |
| `03_failed_sale_rollback.sql` | A failing sale leaves no partial rows |
| `04_isolation_read_committed_session_A/B.sql` | READ COMMITTED: non-repeatable read |
| `05_repeatable_read_session_A/B.sql` | REPEATABLE READ: stable snapshot |
| `06_repeatable_read_conflict_session_A.sql` | REPEATABLE READ: write conflict error (uses `05_..._session_B.sql` as B) |
| `07_concurrency_setup.sql` | Reset: product 6 has exactly 1 unit |
| `08_lost_update_session_A/B.sql` | **The concurrency problem**: two sales of one unit (no lock) |
| `09_for_update_session_A/B.sql` | **The control mechanism**: `SELECT ... FOR UPDATE` |
| [evidence/](evidence/) | One screenshot per script, named like the script (for example `Shuaib_Ganiyat_301910988_08_lost_update_session.png`) |


## How to run
Load the connection string first. `.env` is in the project root, so from this folder use `source ../.env` (every new terminal needs this again) and check that it printed a URL. Portfolio 1's schema and seed must already be loaded.

```bash
source ../.env
echo "$DATABASE_URL"
psql "$DATABASE_URL" -f sql/Shuaib_Ganiyat_301910988_01_commit_rollback.sql
psql "$DATABASE_URL" -f sql/Shuaib_Ganiyat_301910988_02_sale_transaction.sql    
psql "$DATABASE_URL" -f sql/Shuaib_Ganiyat_301910988_03_failed_sale_rollback.sql
```

For every "session A/B" exercise (04 to 09), open **two terminals**, run `source ../.env` in both, and use the **direct** Neon connection string (not the `-pooler` host; pooled connections can break multi-statement transactions). Each script has comments saying which steps to run in which session and when to pause. For 08 and 09, run `Shuaib_Ganiyat_301910988_07_concurrency_setup.sql` first. To leave `psql`, type `\q`.

The tests change stock. To return to the clean data set, reset the database and re-run the Portfolio 1 schema and seed (see `../portfolio-1-database-design/README.md`). The concurrency demos skip ledger rows to stay short; `07_concurrency_setup.sql` re-aligns the ledger for product 6.

## Concepts (short)
- **ACID**: *Atomic* (all or nothing), *Consistent* (constraints always hold), *Isolated* (concurrent transactions don't see each other's half-finished work), *Durable* (committed data survives a crash).
- **Atomicity here:** a sale writes to `sales`, `sale_items`, `payments`, `inventory_movements` and `products`. If the stock check fails, none of it must remain (`03_failed_sale_rollback.sql`).
- **READ COMMITTED** (PostgreSQL default): every statement sees the latest committed data, so two identical SELECTs in one transaction can differ.
- **REPEATABLE READ:** the transaction sees one snapshot taken at its first statement. If it then tries to update a row that someone else changed since, PostgreSQL aborts it with `could not serialize access due to concurrent update`, and the application must retry.
- **The race (demo 1):** both sessions read stock = 1, both decide "enough stock", both sell. This is a read-modify-write race, and it is **not** prevented by READ COMMITTED.
- **The fix (demo 2):** `SELECT ... FOR UPDATE` locks the row at the moment of the check. The second session waits, then sees the committed value 0 and stops. The lock is released at COMMIT/ROLLBACK.
- **Why `FOR UPDATE` when `UPDATE` already locks rows?** Because the UPDATE comes *after* the check. Without the lock on the read, the check and the write are two separate moments and the other session can slip in between.

## Results
| Test | What you did | What you observed | Evidence file |
|---|---|---|---|
| Commit (01-A) | stock/ledger before and after | Product 1: counter 23, ledger 23 before. Restocked 3 and committed: counter 26, ledger 26. Difference 0. | `evidence/Shuaib_Ganiyat_301910988_01_commit_rollback.png` |
| Rollback (01-B) | stock/ledger before and after | Restocked 100 inside a transaction: counter 126, ledger 126. After ROLLBACK both back to 26. Difference 0. | `evidence/Shuaib_Ganiyat_301910988_01_commit_rollback.png` |
| Atomic sale (02) | sale 1 unit and 3 units; payment of the 3-unit sale | Sale 3: 1 x Rice 50kg = 85,000, paid 85,000. Sale 4: 3 x Beans 25kg = 126,000, paid 126,000. Rice stock 26 to 25, Beans 17 to 14. Counter = ledger for both. | `evidence/Shuaib_Ganiyat_301910988_02_sale_transaction.png` |
| Failed sale (03) | row counts before and after | Request for 9999 units gave `ERROR: Insufficient stock. Available: 25, requested: 9999`. Counts before and after identical: sales 4, sale_items 6, payments 4, movements 13, stock of product 1 = 25. | `evidence/Shuaib_Ganiyat_301910988_03_failed_sale_rollback.png` |
| Read Committed (04) | value in query 1 vs query 2 | Query 1 showed 25. After session B committed a change, query 2 in the same transaction showed 24. | `evidence/Shuaib_Ganiyat_301910988_04_isolation_read_committed_session.png` |
| Repeatable Read (05) | value in query 1, 2 and 3 | Query 1: 23. Query 2 (after B committed): still 23. Query 3 (after my COMMIT): 22. | `evidence/Shuaib_Ganiyat_301910988_05_repeatable_read_session.png` |
| Write conflict (06) | the error message | Snapshot showed 22. After B committed, my UPDATE failed with `ERROR: could not serialize access due to concurrent update`; the transaction was aborted and I rolled back. | `evidence/Shuaib_Ganiyat_301910988_06_repeatable_read_conflict_session.png` |
| Lost update (08) | rows in "Concurrency demo%" sales; final stock | Both sessions read stock 1. Two sales were created (Concurrency demo A and B, 1 unit each) but final stock was 0, so 2 units were sold from a stock of 1. | `evidence/Shuaib_Ganiyat_301910988_08_lost_update_session.png` |
| FOR UPDATE (09) | what session B did; rows; final stock | Session B's `SELECT ... FOR UPDATE` waited until A committed, then returned 0 and B rolled back. One sale (Concurrency demo A); final stock 0. | `evidence/Shuaib_Ganiyat_301910988_09_for_update_session.png` |


