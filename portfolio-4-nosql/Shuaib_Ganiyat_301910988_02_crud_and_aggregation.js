// Portfolio 4: CRUD and aggregation.
// Run:  mongosh "YOUR_CONNECTION_STRING" --file 02_crud_and_aggregation.js
// (or paste one section at a time into an interactive mongosh session).
// Run 01_setup_and_seed.js first; re-run it to reset the data after this script.

db = db.getSiblingDB('adetwin_stores_nosql');
const show = (title, value) => { print('\n=== ' + title); printjson(value); };

// ------------------------------------------------------------------ READ
show('R1 Grain products',
  db.products.find({ category: 'Grains' }, { _id: 0, productCode: 1, name: 1, price: 1 }).toArray());

show('R2 Low stock (<= 15)',
  db.products.find({ stock: { $lte: 15 } }, { _id: 0, productCode: 1, name: 1, stock: 1 }).sort({ stock: 1 }).toArray());

// Flexible attributes: query a field that only SOME products have.
show('R3 Products with 12 or more bottles per pack (nested attribute)',
  db.products.find({ 'attributes.bottlesPerPack': { $gte: 12 } }, { _id: 0, name: 1, attributes: 1 }).toArray());

// Array query: which sales contain a given product?
show('R4 Sales that contain GR-001 (query inside the items array)',
  db.sales.find({ 'items.productCode': 'GR-001' }, { _id: 0, saleCode: 1, total: 1, paymentStatus: 1 }).toArray());

// ---------------------------------------------------------------- UPDATE
show('U1 Change price of Vegetable Oil 5L to 13000',
  db.products.updateOne({ productCode: 'CE-001' }, { $set: { price: 13000, updatedAt: new Date() } }));
// Note: the old sale ADS-1001 still shows unitPrice 12500. Sale documents keep
// the price at the time of sale (a deliberate snapshot, as unit_price in PostgreSQL).

// A customer pays more of their debt: push a payment, then recompute the status.
show('U2a Add a 50,000 cash payment to ADS-1002',
  db.sales.updateOne({ saleCode: 'ADS-1002' },
    { $push: { payments: { amount: 50000, method: 'cash', reference: 'CASH-0002', paidAt: new Date() } } }));
show('U2b Recompute paymentStatus from the payments array',
  db.sales.updateOne({ saleCode: 'ADS-1002' }, [
    { $set: { paymentStatus: { $cond: [
        { $gte: [{ $sum: '$payments.amount' }, '$total'] }, 'paid', 'partially_paid'] } } }
  ]));

// Atomic stock deduction: the condition and the change happen in ONE operation
// on ONE document, so two buyers cannot both take the last unit.
show('U3a Sell 1 Malt Drink Pack (stock is enough: matchedCount 1)',
  db.products.updateOne({ productCode: 'BV-001', stock: { $gte: 1 } }, { $inc: { stock: -1 } }));
db.inventoryEvents.insertOne({ productCode: 'BV-001', eventType: 'sale', quantityChange: -1, eventDate: new Date(), reference: 'DEMO' });
show('U3b Try to sell 1000 (not enough stock: matchedCount 0, nothing changes)',
  db.products.updateOne({ productCode: 'BV-001', stock: { $gte: 1000 } }, { $inc: { stock: -1000 } }));

// ---------------------------------------------------------- INSERT / DELETE
show('I1 Insert a new product (attributes differ from every other product)',
  db.products.insertOne({ productCode: 'PA-001', name: 'Spaghetti Carton', category: 'Pasta', price: 11000,
    stock: 40, active: true, attributes: { packetsPerCarton: 20, packetGrams: 500, cookingMinutes: 10 } }));
show('D1 Delete the demonstration product',
  db.products.deleteOne({ productCode: 'PA-001' }));
show('D2 It is gone (expect null)', db.products.findOne({ productCode: 'PA-001' }));

// ------------------------------------------------------------ AGGREGATION
show('A1 Sales value by payment status',
  db.sales.aggregate([
    { $group: { _id: '$paymentStatus', salesValue: { $sum: '$total' }, saleCount: { $sum: 1 } } },
    { $sort: { _id: 1 } }
  ]).toArray());

show('A2 Amount paid and outstanding per sale (from embedded payments)',
  db.sales.aggregate([
    { $project: { _id: 0, saleCode: 1, total: 1,
        amountPaid: { $sum: '$payments.amount' },
        outstanding: { $subtract: ['$total', { $sum: '$payments.amount' }] } } },
    { $sort: { saleCode: 1 } }
  ]).toArray());

show('A3 Revenue per product ($unwind turns each item into its own row)',
  db.sales.aggregate([
    { $unwind: '$items' },
    { $group: { _id: '$items.productCode', unitsSold: { $sum: '$items.quantity' },
                revenue: { $sum: { $multiply: ['$items.quantity', '$items.unitPrice'] } } } },
    { $sort: { revenue: -1 } }
  ]).toArray());

// Stored totals are redundant data: prove they match the items.
show('A4 Does each stored total equal the sum of its items?',
  db.sales.aggregate([
    { $project: { _id: 0, saleCode: 1, total: 1,
        computedTotal: { $sum: { $map: { input: '$items', as: 'i',
          in: { $multiply: ['$$i.quantity', '$$i.unitPrice'] } } } } } },
    { $set: { matches: { $eq: ['$total', '$computedTotal'] } } },
    { $sort: { saleCode: 1 } }
  ]).toArray());

// The MongoDB version of v_stock_reconciliation: counter vs event ledger.
show('A5 Stock counter vs inventory events (difference should be 0)',
  db.inventoryEvents.aggregate([
    { $group: { _id: '$productCode', ledger: { $sum: '$quantityChange' } } },
    { $lookup: { from: 'products', localField: '_id', foreignField: 'productCode', as: 'p' } },
    { $unwind: '$p' },
    { $project: { _id: 0, productCode: '$_id', ledger: 1, stock: '$p.stock',
                  difference: { $subtract: ['$p.stock', '$ledger'] } } },
    { $sort: { productCode: 1 } }
  ]).toArray());
