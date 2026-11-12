# Advanced Database Systems Portfolio (MIT 8103)

**Course:** MIT 8103 Advanced Database Systems, Miva Open University, 2026/2027 first semester CA
**Student:** Ganiyat (GitHub: `gharneeyart`)

## Selected Case Study: Adetwin Stores POS and Inventory Management System

Adetwin Stores is a retail and wholesale business selling packaged
foodstuff (rice, beans, oils, sugar, garri and similar groceries). The
database supports its point-of-sale and stock records.

| Element | Description |
|---|---|
| Nature of the system | POS and inventory management for a grocery store, with cash and credit sales |
| Users | Cashiers, store managers, inventory clerks |
| Major data | Customers, categories, products, sales (receipts), sale items, payments, inventory movements |
| Key operations | Record a sale, take full or part payments, calculate outstanding balances, update stock, record stock received and adjustments, report on sales and stock |

The full statement is in
[portfolio-1-database-design/CASE_STUDY.md](portfolio-1-database-design/CASE_STUDY.md).
The same case study is used in every portfolio.

## Repository Structure

```
advanced-database-portfolio/
├── portfolio-1-database-design/        ER diagram, schema, seed data, normalisation, constraint tests
├── portfolio-2-query-optimisation/     business queries, EXPLAIN ANALYZE, indexes, performance analysis
├── portfolio-3-transactions-concurrency/  commit, rollback, lost update and locking, isolation
├── portfolio-4-nosql/                  MongoDB Atlas document model (Mongoose)
├── portfolio-5-distributed-cloud/      replication, availability, sharding (written) and Neon / Atlas evidence
├── ai-use-log.md                       AI Use Declaration log
└── README.md
```

| Portfolio | Status |
|---|---|
| 1 Database design and modelling | Done |
| 2 Query processing and optimisation | Done |
| 3 Transactions and concurrency | Done |
| 4 NoSQL and advanced data models | Scripts and documentation done; run on Atlas and add screenshots |
| 5 Distributed and cloud database | Discussion written; collect Neon and Atlas evidence |

## How to Run Everything

The complete step-by-step procedure, with what to expect, what to look out for and which evidence to save, is in **[TESTING_GUIDE.md](TESTING_GUIDE.md)**.

Short version (PostgreSQL on Neon, MongoDB on Atlas; connection strings are set as environment variables, see `.env.example`):

```bash
export DATABASE_URL="postgresql://..."
psql "$DATABASE_URL" -f portfolio-1-database-design/schema.sql \
                     -f portfolio-1-database-design/seed.sql
```

Each portfolio folder has its own README.

## AI Use Declaration

See [ai-use-log.md](ai-use-log.md) for the tool used, what it was used
for, and how the output was checked.
