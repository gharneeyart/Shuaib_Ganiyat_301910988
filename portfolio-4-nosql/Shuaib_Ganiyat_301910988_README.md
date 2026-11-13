# Portfolio 4 – NoSQL and Advanced Data Models

Case study: Adetwin Stores. Model: **document store (MongoDB)**. The data matches the PostgreSQL seed (6 products, 2 sales). Design reasoning, embed-vs-reference table, suitability and trade-offs: [Shuaib_Ganiyat_301910988_MODEL_NOTES.md](Shuaib_Ganiyat_301910988_MODEL_NOTES.md).

## What is mongosh?
`mongosh` is the MongoDB Shell, a command-line client that works like `psql` does for PostgreSQL. It is different from Mongoose, which is a Node.js library used inside application code. This portfolio tests the database directly, so it uses `mongosh`.
```bash
brew install mongosh
```
Keep the connection string out of GitHub.

## Files
All files are prefixed `Shuaib_Ganiyat_301910988_`. The prefix is left out of the table below to keep it readable.

| File | Purpose |
|---|---|
| `01_setup_and_seed.js` | Creates 3 collections with validators, loads data, creates indexes |
| `02_crud_and_aggregation.js` | Read, update, insert, delete and 5 aggregations |
| `03_indexing_and_explain.js` | `explain("executionStats")` before and after a compound index |
| `04_validation_tests.js` | 10 PASS/FAIL tests of unique indexes and validators |
| `MODEL_NOTES.md` | Model, embed vs reference, suitability, trade-offs |
| [evidence/](evidence/) | Screenshots: `01-seed`, `01a-documents`, `01b-documents`, `01c-validator`, `02a-queries`, `02b-updates`, `02c-aggregations`, `03a-explain-before`, `03b-explain-after`, `04-validation` |

## How to run
The scripts select the database `adetwin_stores_nosql` themselves (`db.getSiblingDB(...)`), and `MONGODB_URI` comes from `.env` in the project root (see `.env.example`). Put the URI in double quotes in `.env` because it contains `&`.

```bash
source ../.env
echo "$MONGODB_URI"     # must print mongodb+srv://...; if empty, mongosh tries localhost and fails with ECONNREFUSED 127.0.0.1:27017

mongosh "$MONGODB_URI" --file Shuaib_Ganiyat_301910988_01_setup_and_seed.js
mongosh "$MONGODB_URI" --file Shuaib_Ganiyat_301910988_02_crud_and_aggregation.js
mongosh "$MONGODB_URI" --file Shuaib_Ganiyat_301910988_03_indexing_and_explain.js
mongosh "$MONGODB_URI" --file Shuaib_Ganiyat_301910988_04_validation_tests.js
```
Run 01 first. It **drops and recreates** the three collections, so running it again resets the data (do that after 02, which changes it).

To look at the data interactively, start `mongosh "$MONGODB_URI"` and switch to the right database first, because the shell opens in the database named in the URI (for example `adetwin_db`), which stays empty:
```js
use adetwin_stores_nosql
db.products.find().pretty()
db.sales.find().pretty()
db.inventoryEvents.find().pretty()
```
Type `exit` (or press Ctrl+D) to leave `mongosh`. If the connection times out even though the URI prints correctly, check that Atlas allows connections from your network.

## Expected results (compare with what you actually get)
| Script | Expected |
|---|---|
| 01 | Products 6, Sales 2, Inventory events 10 |
| 02 R1 / R2 / R3 / R4 | 2 grain products; Tomato Paste (12) and Laundry Soap (15); Malt Drink Pack; sale ADS-1002 |
| 02 U3a / U3b | matchedCount 1 (stock deducted) / matchedCount 0 (nothing changed) |
| 02 A1 | `paid`: 1 sale, 34,500; `partially_paid`: 1 sale, 212,000 (U2 adds 50,000 but 150,000 is still less than 212,000) |
| 02 A3 | revenue per product (Rice 170,000 first) |
| 02 A4 | `matches: true` for both sales |
| 02 A5 | `difference: 0` for all six products |
| 03 | BEFORE: `COLLSCAN`, examines the whole collection (20,010 documents after a fresh 01, 20,011 if 02 ran first); AFTER: `IXSCAN`, 20 documents examined |
| 04 | T1–T10 all PASS |

## Results
| Test | What you observed | Evidence file |
|---|---|---|
| Seed counts (01) | Printed `Products: 6`, `Sales: 2`, `Inventory events: 10`. | `evidence/Shuaib_Ganiyat_301910988_01-seed.png` |
| Queries R1–R4 (02) | R1: Beans 25kg and Rice 50kg. R2: Tomato Paste Carton (12) and Laundry Soap Carton (15). R3: Malt Drink Pack (nested `attributes.bottlesPerPack` = 12). R4: sale ADS-1002 contains GR-001. | `evidence/Shuaib_Ganiyat_301910988_02a-queries.png` |
| Updates U1–U3 (02) | U1: price update `modifiedCount: 1`. U2a: 50,000 payment added `modifiedCount: 1`; U2b status recompute `modifiedCount: 0` (ADS-1002 stays `partially_paid`). U3a: `matchedCount: 1`, Malt Drink Pack stock 19 to 18. U3b: `matchedCount: 0`, nothing changed. I1/D1/D2: product inserted, deleted (`deletedCount: 1`), lookup returned `null`. | `evidence/Shuaib_Ganiyat_301910988_02b-updates.png` |
| Aggregations A1–A5 (02) | A1: paid 34,500 (1 sale), partially_paid 212,000 (1 sale). A2: ADS-1001 paid 34,500, outstanding 0; ADS-1002 paid 150,000, outstanding 62,000. A3: Rice 50kg highest at 170,000. A4: `matches: true` for both sales. A5: `difference: 0` for all six products. | `evidence/Shuaib_Ganiyat_301910988_02c-aggregations.png` |
| explain before: stage, docs examined, ms (03) | `COLLSCAN` then `SORT`; `totalDocsExamined: 20011`, `totalKeysExamined: 0`, `nReturned: 20`, `executionTimeMillis: 16`. The collection held 20,011 documents because script 02 had added one `DEMO` stock event (U3a) before 03 was run; after a fresh 01 the figures are 20,010 documents examined. | `evidence/Shuaib_Ganiyat_301910988_03a-explain-before.png` |
| explain after: stage, docs examined, ms (03) | `IXSCAN` on `productCode_1_eventDate_-1` then `FETCH` then `LIMIT`; `totalDocsExamined: 20`, `totalKeysExamined: 20`, `nReturned: 20`, `executionTimeMillis: 1`. The 20,000 synthetic events were then deleted (back to 11 documents: the 10 seed events plus the `DEMO` event from 02; 10 after a fresh 01). | `evidence/Shuaib_Ganiyat_301910988_03b-explain-after.png` |
| Validation tests (04) | T1 to T10 all PASS. T1 and T9: duplicate key (code 11000). T2 to T8: validator rejections (code 121). T10: a sale line for a non-existent product was accepted (MongoDB has no foreign keys), then removed. | `evidence/Shuaib_Ganiyat_301910988_04-validation.png` |

## Notes on the evidence
- The screenshots were taken in the order 01, 02, 03, 04 **without re-running 01 in between**. Script 02 changes the data (oil price 13000, Malt Drink Pack stock 18, an extra 50,000 payment on ADS-1002, one `DEMO` stock event), so after 02 the MongoDB data no longer mirrors the PostgreSQL seed. Re-run 01 to reset it.
- The 01 screenshots (`01a-documents`, `01b-documents`, `01c-validator`) show the seed documents and the products validator before 02 was run, so they still show the original prices and stock.
- MongoDB holds customers only as snapshots inside each sale (`customer.customerId`, name, type). There is no separate `customers` collection.

