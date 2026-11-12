# Adetwin Stores POS and Inventory Management System

## Case Study

Adetwin Stores is a retail and wholesale business that sells packaged
foodstuff such as noodles, spaghetti, oils, and other grocery products. The
store needs a database system to manage its products, stock, sales,
customers, and payments.

The proposed Point of Sale (POS) and Inventory Management System will
store product information, record sales transactions, track the items
sold on each receipt, and maintain customer records. It will also
support cash and credit sales, including fully paid, partially paid, and
unpaid transactions. For credit sales, the system must identify the
customer, record each payment received, and calculate the outstanding
balance.

The system will track stock received, stock sold, and stock adjustments.
It will maintain current stock quantities and a history of inventory
movements to help the store monitor its stock and identify
discrepancies.

The purpose of the system is to improve record keeping, reduce errors,
make sales and payment information easier to retrieve, and support
better inventory management and business decisions.

## Intended Users

Cashiers: Record sales, products sold, and payments received.

Store managers: Review sales, monitor outstanding balances, and oversee store operations.

Inventory clerks: Maintain stock records, record stock received, and document inventory adjustments.

## Key Database Operations

1.  Add and update products, categories and prices.
2.  Record a sale (receipt) with several product lines.
3.  Record one or more payments against a sale, including part payments.
4.  Calculate the outstanding balance of a sale or customer.
5.  Update stock on every sale and record an inventory movement.
6.  Record stock received (`restock`), opening stock, returns and stock
    adjustments as inventory movements.
7.  Cancel a sale (the record is kept, not deleted) and return its stock.
8.  Report on sales, collections by payment method, stock levels and
    inventory value.

## Case Study Selection

The brief asks each student to choose a realistic organisation. Adetwin
Stores is a realistic retail/wholesale business (a proposed case study
rather than one of the sample organisations listed in the brief). It is
modelled as a single store. It supports all five portfolio activities:
relational design, SQL queries, transactions on stock and payments, a
document model for products and receipts, and a distributed/cloud
deployment discussion (a multi-branch store is the growth scenario used
in Portfolio 5).

Out of scope, stated deliberately: delivery tracking, product attribute
variants, supplier and purchase orders, and user accounts. They are not
needed by the portfolio tasks.

## Main Business Rules

1.  A receipt can contain multiple products, and each product appears on a
    receipt only once; each line records its quantity and the selling
    price at the time of sale.
2.  Walk-in sales may have no customer record; if a customer ID is
    supplied, it must refer to an existing customer. Credit sales should
    be linked to a customer; the database does not enforce this (it is
    left to the application, see `Shuaib_Ganiyat_301910988_Database_Design.md`).
3.  A sale can receive multiple payments, including partial payments.
4.  Outstanding balance equals the sale total minus payments received.
    It is calculated, not stored.
5.  A customer is either `retail` or `wholesale`.
6.  Each inventory movement belongs to a product and records a stock
    change: sales reduce stock; opening stock, restocks and returns
    increase it; adjustments may do either.
7.  Stock quantities cannot be negative, and the current stock must agree
    with the total of the movement history.
8.  A sale is never deleted. It is marked `cancelled`, with the time of
    cancellation.
9.  Recording a sale, its items, payment records, and related stock
    changes must be handled consistently (a single database
    transaction, see Portfolio 3).
10. A category can contain many products.
