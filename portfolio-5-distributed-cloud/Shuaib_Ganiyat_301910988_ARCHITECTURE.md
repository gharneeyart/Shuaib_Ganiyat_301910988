# Portfolio 5 – Distributed and Cloud Database Design (Adetwin Stores)

## 1. Deployment
| | PostgreSQL | MongoDB |
|---|---|---|
| Service | Neon (managed PostgreSQL) | MongoDB Atlas, tier `Free (M0)`, cluster `Cluster0`, 512 MB limit |
| Region | `AWS US East 2 (Ohio)` | `AWS / Paris (eu-west-3)` |
| Version | `18.6` (from `SELECT version()`) | `8.0.37` |
| Nodes | one primary compute (+ storage layer managed by Neon) | `3` nodes (replica set: 1 primary, 2 secondaries) (from `db.hello().hosts`) |
| Role | **System of record**: sales, payments, stock, customers | **Derived read model**: product documents, sale snapshots, stock events |
| Access control | TLS required (`sslmode=require`; `\conninfo` shows TLSv1.3 from my machine to Neon), single role `neondb_owner` (owns `neondb`); password kept in `.env`, not in Git | Atlas IP access list: two specific addresses (`/32`) plus `0.0.0.0/0` (open to all; temporary, to be removed); database user `shuaibganiyat20_db_user` with role `atlasAdmin` (full rights, not least privilege; a real deployment would use `readWrite` on one database) |
| Backup / recovery | "Restore from history" with a 6-hour history window (Backup & Restore page); compute size 0.25 to 2 CU, autosuspends when idle | backups inactive on the Free tier ("Enable daily backups" is not available); the 3-node replica set gives copies but is not a backup |

## 2. Architecture
```text
                Store staff (POS / SQL client)
                       |                 |
          writes + critical reads        catalogue / receipt reads
                       v                 v
   +--------------------------+    +-------------------------------------+
   | Neon PostgreSQL PRIMARY  |    | Atlas replica set                   |
   | (system of record)       |    |  PRIMARY  <-- writes                |
   |  customers, products,    |    |  SECONDARY, SECONDARY (replicate)   |
   |  sales, payments, stock  |    |  products, sales, inventoryEvents   |
   +--------------------------+    +-------------------------------------+
        :  (proposal)                       ^
        v                                   |  changes flow ONE way
   [ Neon read replica ]  ......... outbox / change feed (proposal)
```
Solid boxes exist in this project. The Neon read replica and the change feed are proposals.

## 3. Replication: what is read from where
The primary takes all writes. A replica is a read-only copy that can lag behind. Which reads may use stale data?

| Operation | Needs the latest data? | Read from | Reason |
|---|---|---|---|
| Record a sale (check stock, deduct) | **Yes** | primary only | This is the check-then-act race from Portfolio 3. `SELECT ... FOR UPDATE` only works on the primary, and a stale replica would let two cashiers sell the last unit again. |
| Take a payment / show a customer's outstanding balance | **Yes** | primary | Money; a stale balance could cause double collection. |
| Browse the product catalogue | No (seconds of lag is fine) | replica / secondary | Heavy reads should not slow the till. |
| Daily revenue and top-product reports (Portfolio 2 queries) | No | replica | Long aggregations; yesterday's figures do not change. |
| Stock movement audit history | No | replica | Append-only history. |

**Implemented:** Atlas replication (verify with `02_mongo_replica_check.js`). **Proposed:** a Neon read replica for the three "No" rows.

## 4. Consistency
- **PostgreSQL:** full ACID inside one database (Portfolio 3). Isolation level READ COMMITTED by default.
- **MongoDB:** atomic per document; `w:majority` makes a write survive a primary failure; reads from a secondary are eventually consistent (`02_mongo_replica_check.js` shows the cost of `w:majority`).
- **Across the two databases there is no shared transaction.** Failure case: a sale commits in PostgreSQL, then the write of its snapshot to MongoDB fails. PostgreSQL is the truth; MongoDB must be repairable from it. **Proposed fix, outbox pattern:** in the same PostgreSQL transaction as the sale, insert a row into an `outbox` table. A background job reads unsent rows, writes the document to MongoDB (idempotently, keyed by `saleCode`), then marks the row sent. If MongoDB is down the job retries later and nothing is lost.
- **CAP/PACELC by operation:** payments and stock deduction choose **consistency** (refuse or wait rather than act on stale data). Catalogue browsing chooses **availability and speed** (a stale price for a few seconds is acceptable).

## 5. Availability and failure scenarios
These describe expected provider behaviour and the application's duty. Only the Neon cold start is measured here.

| Failure | Expected behaviour | What the application must do |
|---|---|---|
| Neon compute idle | Suspended after inactivity; first query is slower (**measured** in `01_neon_checks.sql`) | Tolerate a slow first request; retry on connection errors |
| Atlas primary fails | The replica set elects a new primary (typically seconds); drivers reconnect | Retry writes; make them idempotent (e.g. unique `saleCode`) so a retry cannot create a second sale |
| Network drop mid-transaction | PostgreSQL rolls the transaction back (Portfolio 3) | Retry the whole sale; use a unique payment reference so a retry cannot double-charge |
| Provider outage in the region | Both services unavailable | Out of scope; mention a multi-region standby as the next step |

## 6. Sharding (proposal only; a single store does not need it)
Sharding splits one logical dataset across servers by a **shard key**. It becomes relevant if Adetwin grows to many branches and `sales`/`inventoryEvents` outgrow one server.

| Candidate key | Good | Bad |
|---|---|---|
| `store_id` | Most queries are per store, so data stays together | One very large store becomes a hot shard |
| region | Data near its users | Uneven regions; moving a store means moving data |
| `sale_date` | Easy archiving of old data | Today's sales all hit one shard (hot spot) |
| hashed `sale_id` | Even spread | Every per-store report must ask all shards |

**Proposed choice:** a compound key `(store_id, sale_date)`. Data stays per store and a store's data is still spread over time. **Cross-shard cost:** company-wide reports (top products across all stores, customers who owe in any store) must query every shard and merge the results (scatter-gather), and a foreign key cannot span shards.

**Single-server step before sharding: PostgreSQL range partitioning** (sketch only; **not applied**):
```sql
-- Sketch. Not run in this project.
CREATE TABLE sales_partitioned (
    sale_id BIGINT NOT NULL, customer_id BIGINT, sale_date TIMESTAMPTZ NOT NULL,
    sale_status VARCHAR(20) NOT NULL,
    PRIMARY KEY (sale_id, sale_date)           -- the partition key must be part of the key
) PARTITION BY RANGE (sale_date);
CREATE TABLE sales_2026_10 PARTITION OF sales_partitioned
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
```
Trade-off: child tables such as `sale_items` would also need `sale_date` to reference it.

## 7. Implemented vs proposed
| Item | Status |
|---|---|
| Neon cloud PostgreSQL deployment, TLS, primary check, cold-start timing | **Implemented** (`01_neon_checks.sql`) |
| MongoDB Atlas replica set, write concern and read preference comparison | **Implemented** (`02_mongo_replica_check.js`) |
| Neon read replica | Proposed |
| Outbox / change feed between the two databases | Proposed |
| Sharding and PostgreSQL partitioning | Proposed (design only) |
| Failover test, backup restore test | Not performed |

## 8. Limitations
What was **not** done in this project, and why it does not change the results above:

- **No PostgreSQL replica was set up.** Neon runs one primary database here. Section 3 explains how a read replica would be used and which reads must stay on the primary, but that part is a design, not something I built.
- **No failover was tested.** I did not stop the primary to see another node take over. MongoDB Atlas does this automatically with its three nodes, but I only inspected the replica set (`02_mongo_replica_check.js`); I did not trigger a failover.
- **No sharding.** The shard keys in section 6 are a proposal. A single store with a small data set does not need sharding, and the free MongoDB tier cannot create a sharded cluster.
- **The two databases do not synchronise.** PostgreSQL and MongoDB are separate deployments loaded with the same sample data. A change in one does not reach the other. Section 4 proposes an outbox pattern to fix this, but it was not built.
- **No backup restore test.** I recorded what the consoles offer (restore window, backup option) but did not restore anything.

These are limits of a coursework project on free-tier services, not mistakes in the design. Each item is listed as "proposed" or "not performed" in section 7, so nothing here is presented as built when it is not.
