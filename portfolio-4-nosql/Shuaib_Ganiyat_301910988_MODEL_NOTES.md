# Portfolio 4 – Data model and suitability

## Model selected: document (MongoDB)
Same case study as the other portfolios (Adetwin Stores), same six products, same two sales, same customers. The documents mirror the PostgreSQL seed so the two models can be compared directly.

## Collections and sample documents
**`products`**: one document per product, with an `attributes` object that differs by product.
```json
{ "productId": 5, "productCode": "BV-001", "name": "Malt Drink Pack", "category": "Beverages",
  "price": 9500, "stock": 19, "active": true,
  "attributes": { "bottlesPerPack": 12, "flavour": "Original", "returnableBottles": true } }
```
Rice has `grainType` and `origin`; oil has `volumeLitres`; soap has `barsPerCarton`. In PostgreSQL this variety would need either many mostly-NULL columns or an EAV table (the open question from Portfolio 1).

**`sales`**: one document per sale, with the customer snapshot, the line items and the payments embedded.
```json
{ "saleCode": "ADS-1002", "saleDate": "2026-10-02T11:30:00Z",
  "customer": { "customerId": 2, "name": "Bello Traders", "type": "wholesale" },
  "items": [ { "productCode": "GR-001", "name": "Rice 50kg", "quantity": 2, "unitPrice": 85000 },
             { "productCode": "GR-002", "name": "Beans 25kg", "quantity": 1, "unitPrice": 42000 } ],
  "total": 212000,
  "payments": [ { "amount": 100000, "method": "transfer", "reference": "TRF-0002" } ],
  "paymentStatus": "partially_paid" }
```

**`inventoryEvents`**: one small document per stock movement (opening, sale, restock...), kept separate.

## Embed or reference? The decision per collection
| Data | Decision | Why |
|---|---|---|
| Items inside a sale | **Embed** | They are always read with the sale, never on their own, and a sale has few lines. One read returns the whole receipt. |
| Payments inside a sale | **Embed** | A sale has a handful of payments, always read with it; `$push` adds one. |
| Customer inside a sale | **Embed a snapshot** (id, name, type) | Keeps the name and type as they were at the time of sale, like `unit_price` in PostgreSQL. |
| Stock movements | **Separate collection** | They grow without limit and are queried by product and date, independently of sales. Embedding them in a product would make the document grow forever. |

## Why MongoDB is suitable here
- **Variable product attributes** without NULL columns or EAV joins, and nested fields can still be queried and indexed (`attributes.bottlesPerPack`).
- **A sale is naturally one document**: show receipt, outstanding balance and history in one read, without joining four tables.
- **Aggregation pipelines** (`$unwind`, `$group`, `$lookup`) summarise embedded arrays: revenue per product, amount paid per sale.
- **Single-document atomicity**: `updateOne({ stock: { $gte: 1 } }, { $inc: { stock: -1 } })` checks and changes stock in one atomic step, so two buyers cannot take the last unit (compare with `SELECT ... FOR UPDATE` in Portfolio 3).

## Why not PostgreSQL JSONB for the attributes?
JSONB would also store flexible attributes next to relational data, and with a GIN index it queries them well. For this system it could be the better engineering choice. MongoDB is used here to demonstrate a document model end to end; it is justified for the *sale* document (one-read receipts) more than for the attributes alone.

## Trade-offs (what is given up)
- **No foreign keys.** `items.productCode` is only a string; MongoDB accepts a sale for a non-existent product (test T10 in `04_validation_tests.js`). The application must check it.
- **Duplicated data** (product name and price inside sales, customer name inside sales). It is intentional as a snapshot, but a renamed customer is not updated in old sales.
- **Redundant totals**: `total` is stored and can disagree with the items. Aggregation A4 checks it.
- **Counter vs ledger** (`products.stock` vs `inventoryEvents`) must be kept in step by the application, as in PostgreSQL. Updating two documents is not atomic unless a multi-document transaction is used (needs a replica set; not used here). Aggregation A5 detects drift.
- Validators replace some CHECK/NOT NULL rules but not foreign keys or cross-document rules.

This portfolio does not synchronise MongoDB with the PostgreSQL database; they are two separate implementations of the same business.
