// Portfolio 4: MongoDB setup and seed data.
// Run:  mongosh "YOUR_CONNECTION_STRING" --file 01_setup_and_seed.js
// The data mirrors the PostgreSQL seed (same 6 products, same 2 sales, same
// customers, same current stock) so both portfolios describe the same business.
// WARNING: drops and recreates the three collections in database adetwin_stores_nosql.

db = db.getSiblingDB('adetwin_stores_nosql');

db.products.drop();
db.sales.drop();
db.inventoryEvents.drop();

// --- Schema validation (the MongoDB counterpart of CHECK / NOT NULL) ----------
db.createCollection('products', {
  validator: { $jsonSchema: {
    bsonType: 'object',
    required: ['productCode', 'name', 'category', 'price', 'stock', 'active'],
    properties: {
      productCode: { bsonType: 'string' },
      name:        { bsonType: 'string' },
      category:    { bsonType: 'string' },
      price:       { bsonType: 'number', minimum: 0 },
      stock:       { bsonType: 'number', minimum: 0 },
      active:      { bsonType: 'bool' },
      attributes:  { bsonType: 'object' }
    }
  } }
});

db.createCollection('sales', {
  validator: { $jsonSchema: {
    bsonType: 'object',
    required: ['saleCode', 'saleDate', 'customer', 'items', 'total', 'payments', 'paymentStatus'],
    properties: {
      saleCode:      { bsonType: 'string' },
      saleDate:      { bsonType: 'date' },
      customer:      { bsonType: 'object', required: ['customerId', 'name'] },
      items: {
        bsonType: 'array', minItems: 1,
        items: { bsonType: 'object', required: ['productCode', 'quantity', 'unitPrice'],
                 properties: { quantity: { bsonType: 'number', minimum: 1 },
                               unitPrice: { bsonType: 'number', minimum: 0 } } }
      },
      total:         { bsonType: 'number', minimum: 0 },
      payments: {
        bsonType: 'array',
        items: { bsonType: 'object', required: ['amount', 'method'],
                 properties: { amount: { bsonType: 'number', minimum: 0.01 },
                               method: { enum: ['cash', 'transfer', 'card'] } } }
      },
      paymentStatus: { enum: ['unpaid', 'partially_paid', 'paid'] }
    }
  } }
});

// --- Products: the same six as PostgreSQL, with genuinely different attributes -
db.products.insertMany([
  { productId: 1, productCode: 'GR-001', name: 'Rice 50kg', category: 'Grains', price: 85000, stock: 23, active: true,
    attributes: { packageSize: '50kg', grainType: 'Long grain parboiled', origin: 'Nigeria' } },
  { productId: 2, productCode: 'GR-002', name: 'Beans 25kg', category: 'Grains', price: 42000, stock: 17, active: true,
    attributes: { packageSize: '25kg', variety: 'Honey beans' } },
  { productId: 3, productCode: 'CE-001', name: 'Vegetable Oil 5L', category: 'Cooking Essentials', price: 12500, stock: 28, active: true,
    attributes: { volumeLitres: 5, oilType: 'vegetable', container: 'jerrycan' } },
  { productId: 4, productCode: 'CE-002', name: 'Tomato Paste Carton', category: 'Cooking Essentials', price: 18000, stock: 12, active: true,
    attributes: { unitsPerCarton: 50, tinSize: '70g' } },
  { productId: 5, productCode: 'BV-001', name: 'Malt Drink Pack', category: 'Beverages', price: 9500, stock: 19, active: true,
    attributes: { bottlesPerPack: 12, flavour: 'Original', returnableBottles: true } },
  { productId: 6, productCode: 'HH-001', name: 'Laundry Soap Carton', category: 'Household', price: 14500, stock: 15, active: true,
    attributes: { barsPerCarton: 24, scent: 'Lemon' } }
]);

db.products.createIndex({ productCode: 1 }, { unique: true });
db.products.createIndex({ category: 1, stock: 1 });

// --- Sales: one document per sale, with customer snapshot, items and payments --
db.sales.insertMany([
  { saleCode: 'ADS-1001', saleDate: ISODate('2026-10-01T09:00:00Z'),
    customer: { customerId: 1, name: 'Amina Yusuf', type: 'retail' },
    items: [
      { productCode: 'CE-001', name: 'Vegetable Oil 5L', quantity: 2, unitPrice: 12500 },
      { productCode: 'BV-001', name: 'Malt Drink Pack',  quantity: 1, unitPrice: 9500 }
    ],
    total: 34500,
    payments: [{ amount: 34500, method: 'cash', reference: 'CASH-0001', paidAt: ISODate('2026-10-01T09:05:00Z') }],
    paymentStatus: 'paid' },
  { saleCode: 'ADS-1002', saleDate: ISODate('2026-10-02T11:30:00Z'),
    customer: { customerId: 2, name: 'Bello Traders', type: 'wholesale' },
    items: [
      { productCode: 'GR-001', name: 'Rice 50kg',  quantity: 2, unitPrice: 85000 },
      { productCode: 'GR-002', name: 'Beans 25kg', quantity: 1, unitPrice: 42000 }
    ],
    total: 212000,
    payments: [{ amount: 100000, method: 'transfer', reference: 'TRF-0002', paidAt: ISODate('2026-10-02T11:35:00Z') }],
    paymentStatus: 'partially_paid' }
]);

db.sales.createIndex({ saleCode: 1 }, { unique: true });
db.sales.createIndex({ 'customer.customerId': 1 });
db.sales.createIndex({ saleDate: 1 });

// --- Stock ledger as separate documents (opening stock + the two sales) --------
// SUM(quantityChange) per product equals products.stock.
const opening = ISODate('2025-12-31T07:00:00Z');
db.inventoryEvents.insertMany([
  { productCode: 'GR-001', eventType: 'opening', quantityChange: 25, eventDate: opening },
  { productCode: 'GR-002', eventType: 'opening', quantityChange: 18, eventDate: opening },
  { productCode: 'CE-001', eventType: 'opening', quantityChange: 30, eventDate: opening },
  { productCode: 'CE-002', eventType: 'opening', quantityChange: 12, eventDate: opening },
  { productCode: 'BV-001', eventType: 'opening', quantityChange: 20, eventDate: opening },
  { productCode: 'HH-001', eventType: 'opening', quantityChange: 15, eventDate: opening },
  { productCode: 'CE-001', eventType: 'sale', quantityChange: -2, eventDate: ISODate('2026-10-01T09:00:00Z'), reference: 'ADS-1001' },
  { productCode: 'BV-001', eventType: 'sale', quantityChange: -1, eventDate: ISODate('2026-10-01T09:00:00Z'), reference: 'ADS-1001' },
  { productCode: 'GR-001', eventType: 'sale', quantityChange: -2, eventDate: ISODate('2026-10-02T11:30:00Z'), reference: 'ADS-1002' },
  { productCode: 'GR-002', eventType: 'sale', quantityChange: -1, eventDate: ISODate('2026-10-02T11:30:00Z'), reference: 'ADS-1002' }
]);

print('Adetwin MongoDB sample data loaded.');
print('Products: ' + db.products.countDocuments());          // expected 6
print('Sales: ' + db.sales.countDocuments());                // expected 2
print('Inventory events: ' + db.inventoryEvents.countDocuments());  // expected 10
