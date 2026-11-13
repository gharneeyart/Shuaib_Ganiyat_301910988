# Entity-Relationship (ER) Diagram – Adetwin Stores

The Adetwin Stores database has seven entities: `CUSTOMERS`, `CATEGORIES`,
`PRODUCTS`, `SALES`, `SALE_ITEMS`, `PAYMENTS`, and `INVENTORY_MOVEMENTS`.

Reading guide:
- A walk-in sale has no customer, so `customers` to `sales` is zero-or-many on the sales side and **optional** on the customer side (nullable FK).
- `sale_items` depends on `sales` for its identity (a line has no meaning without its sale).
- A completed sale is expected to have at least one line, but the database does not enforce this, so `sales` to `sale_items` is drawn as zero-or-many. The application adds the lines in the same transaction as the sale (Portfolio 3).
- `inventory_movements` to `sale_items` is optional: opening, restock and adjustment movements have no sale line. A sale line has one `sale` movement and possibly a later `return` movement, so it is zero-or-many in the model.

```mermaid
erDiagram
    CUSTOMERS |o--o{ SALES : "places (walk-in = no customer)"
    CATEGORIES ||--o{ PRODUCTS : classifies
    SALES ||--o{ SALE_ITEMS : contains
    PRODUCTS ||--o{ SALE_ITEMS : "sold as"
    SALES ||--o{ PAYMENTS : receives
    PRODUCTS ||--o{ INVENTORY_MOVEMENTS : "stock history"
    SALE_ITEMS |o--o{ INVENTORY_MOVEMENTS : "causes (sale/return)"

    CUSTOMERS {
      bigint customer_id PK
      varchar customer_name
      varchar phone UK
      varchar customer_type "retail | wholesale"
      timestamptz created_at
    }
    CATEGORIES {
      bigint category_id PK
      varchar category_name UK
    }
    PRODUCTS {
      bigint product_id PK
      varchar product_name
      bigint category_id FK
      numeric current_price
      int quantity_in_stock
      boolean is_active
      timestamptz created_at
    }
    SALES {
      bigint sale_id PK
      bigint customer_id FK "nullable"
      timestamptz sale_date
      varchar sale_status "completed | cancelled"
      timestamptz cancelled_at
      text notes
    }
    SALE_ITEMS {
      bigint sale_item_id PK
      bigint sale_id FK
      bigint product_id FK
      int quantity
      numeric unit_price "price snapshot"
      numeric line_total "generated"
    }
    PAYMENTS {
      bigint payment_id PK
      bigint sale_id FK
      numeric amount
      varchar payment_method "cash | transfer | card"
      timestamptz payment_date
      varchar reference
    }
    INVENTORY_MOVEMENTS {
      bigint movement_id PK
      bigint product_id FK
      bigint sale_item_id FK "nullable"
      varchar movement_type "opening | sale | restock | adjustment | return"
      int quantity_change
      timestamptz movement_date
      text remarks
    }
```

Views (derived, not stored): `v_sale_balances` (outstanding per sale) and `v_stock_reconciliation` (counter vs ledger).
