# Portfolio 5 – Distributed and Cloud Database Exercise

Case study: Adetwin Stores. The design discussion is in [Shuaib_Ganiyat_301910988_ARCHITECTURE.md](Shuaib_Ganiyat_301910988_ARCHITECTURE.md); two small scripts provide deployment evidence.

## Files
All files are prefixed `Shuaib_Ganiyat_301910988_`. The prefix is left out of the table below to keep it readable.

| File | Purpose |
|---|---|
| `ARCHITECTURE.md` | Deployment, diagram, which reads may be stale, consistency across two databases, failure scenarios, sharding proposal, implemented vs proposed |
| `neon_checks.sql` | Neon: version, TLS, primary vs replica, database size, cold-start timing |
| `mongo_replica_check.js` | Atlas: replica set members, `w:1` vs `w:majority` timing, primary vs secondary reads |
| [evidence/](evidence/) | Console screenshots (credentials hidden) and script output |

## How to run
`.env` is in the project root, so from this folder use `source ../.env` (every new terminal needs this again) and check that both variables printed a URL. If a variable is empty, `psql` falls back to a local database and `mongosh` to `127.0.0.1:27017`.

```bash
source ../.env
echo "$DATABASE_URL"
echo "$MONGODB_URI"

# Neon (the saved evidence was taken through the pooled host; the direct string also works)
psql "$DATABASE_URL" -f Shuaib_Ganiyat_301910988_neon_checks.sql

# Atlas
mongosh "$MONGODB_URI" --file Shuaib_Ganiyat_301910988_mongo_replica_check.js
```
Run the commands from the folder that contains the files (`pwd` should end in `portfolio-5-distributed-cloud` inside `Learning-folder/advanced-database-portfolio`). For the cold-start check, run the script once, wait about 10 minutes, reconnect, and run only the last three statements of `Shuaib_Ganiyat_301910988_neon_checks.sql`. Type `\q` to leave `psql` and `exit` to leave `mongosh`.

## Results
| Check | What you observed | Evidence file |
|---|---|---|
| Neon version / region / TLS | PostgreSQL 18.6 (aarch64), database `neondb`, AWS US East 2 (Ohio). `\conninfo` showed `SSL Connection true`, protocol TLSv1.3, cipher TLS_AES_256_GCM_SHA384, so my connection to Neon is encrypted. `pg_stat_ssl` showed `ssl = f` because it reports the hop from Neon's proxy to the compute (127.0.0.1), not my connection. The checks ran through Neon's pooled endpoint (host name ends in `-pooler`). That is fine for these read-only checks; the transaction demos in Portfolio 3 should use the direct (non-pooled) string. | `evidence/Shuaib_Ganiyat_301910988_neon_checks.png`, `evidence/Shuaib_Ganiyat_301910988_neon_checks_2.png` |
| `pg_is_in_recovery()` | `f` (false): the Neon database is the writable primary and there is no read replica. Database size 8,648 kB. | `evidence/Shuaib_Ganiyat_301910988_neon_checks.png` |
| Cold start: first query time vs second; start time before and after idle | `compute_started_at` was 2026-11-12 07:04:27 (uptime 2.3 s, the compute had been suspended overnight) on the first run and 07:12:43 (uptime 1 min 43 s) on a reconnect (the two start times are about 8 minutes apart, and the second check ran roughly 10 minutes after the first). The later start time shows Neon suspended and restarted the compute in between. Every timed query took about 215-330 ms both times (network latency), so the wake-up delay happened while connecting and `\timing` did not show it. The Neon console also showed the compute as SUSPENDED when idle. | `evidence/Shuaib_Ganiyat_301910988_neon_cold_start.png`, `evidence/Shuaib_Ganiyat_301910988_neon_compute.png` |
| Atlas replica set name, primary, member count | Replica set `atlas-tkpwzs-shard-0`, 3 members: primary `ac-l4qv91u-shard-00-01`, secondaries `00-00` and `00-02`. Free tier, MongoDB 8.0.37, AWS Paris (eu-west-3). | `evidence/Shuaib_Ganiyat_301910988_atlas_replica_check.png`, `evidence/Shuaib_Ganiyat_301910988_atlas_cluster.png` |
| Average insert time `w:1` vs `w:majority` | 50 inserts each: `w:1` = 149.0 ms, `w:majority` = 132.0 ms. I expected `w:majority` to be slightly slower, because it waits for a secondary. Both are dominated by the network round trip to Atlas (about 130-150 ms), so the difference is within noise and I do not claim `w:majority` is faster. | `evidence/Shuaib_Ganiyat_301910988_atlas_replica_check.png` |
| Host that served a secondary read | With `readPreference secondary` the read was served by `ac-l4qv91u-shard-00-00`; with `primary` it came from `shard-00-01`. A secondary read can be slightly behind (eventual consistency). | `evidence/Shuaib_Ganiyat_301910988_atlas_replica_check.png` |
| Console: backup / restore settings (screenshot) | Neon: "Restore from history" with a 6-hour window; compute 0.25 to 2 CU. Atlas Free tier: backups inactive ("Enable daily backups" not available), so there is no backup to restore. | `evidence/Shuaib_Ganiyat_301910988_neon_restore.png`, `evidence/Shuaib_Ganiyat_301910988_atlas_cluster.png`  |
