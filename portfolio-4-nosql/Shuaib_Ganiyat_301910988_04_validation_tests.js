// Portfolio 4: tests that MongoDB rejects bad documents (the counterpart of
// Shuaib_Ganiyat_301910988_ConstraintTests.sql in Portfolio 1).
// Run:  mongosh "$MONGODB_URI" --file Shuaib_Ganiyat_301910988_04_validation_tests.js
// Run Shuaib_Ganiyat_301910988_01_setup_and_seed.js first. Prints PASS/FAIL per test; leaves data unchanged.

db = db.getSiblingDB('adetwin_stores_nosql');

const expectError = (label, fn) => {
  try { fn(); print('FAIL  ' + label + ' -- accepted but should have been rejected'); }
  catch (e) { print('PASS  ' + label + ' -- rejected (code ' + e.code + ')'); }
};
const expectOk = (label, fn) => {
  try { fn(); print('PASS  ' + label + ' -- accepted as expected'); }
  catch (e) { print('FAIL  ' + label + ' -- rejected: ' + e.message); }
};

const okProduct = { productCode: 'TST-001', name: 'Test', category: 'Test', price: 10, stock: 1, active: true };

expectError('T1 duplicate productCode (unique index, code 11000)',
  () => db.products.insertOne({ ...okProduct, productCode: 'GR-001' }));
expectError('T2 negative price (validator, code 121)',
  () => db.products.insertOne({ ...okProduct, price: -5 }));
expectError('T3 negative stock',
  () => db.products.insertOne({ ...okProduct, stock: -1 }));
expectError('T4 missing required field (no name)',
  () => { const d = { ...okProduct }; delete d.name; db.products.insertOne(d); });
expectError('T5 price of the wrong type (string)',
  () => db.products.insertOne({ ...okProduct, price: 'cheap' }));
expectError('T6 sale with no items',
  () => db.sales.insertOne({ saleCode: 'TST-S1', saleDate: new Date(), customer: { customerId: 1, name: 'X' },
                             items: [], total: 0, payments: [], paymentStatus: 'unpaid' }));
expectError('T7 invalid paymentStatus',
  () => db.sales.insertOne({ saleCode: 'TST-S2', saleDate: new Date(), customer: { customerId: 1, name: 'X' },
                             items: [{ productCode: 'GR-001', quantity: 1, unitPrice: 1 }], total: 1,
                             payments: [], paymentStatus: 'maybe' }));
expectError('T8 invalid payment method inside the payments array',
  () => db.sales.insertOne({ saleCode: 'TST-S3', saleDate: new Date(), customer: { customerId: 1, name: 'X' },
                             items: [{ productCode: 'GR-001', quantity: 1, unitPrice: 1 }], total: 1,
                             payments: [{ amount: 1, method: 'bitcoin' }], paymentStatus: 'paid' }));
expectError('T9 duplicate saleCode',
  () => db.sales.insertOne({ saleCode: 'ADS-1001', saleDate: new Date(), customer: { customerId: 1, name: 'X' },
                             items: [{ productCode: 'GR-001', quantity: 1, unitPrice: 1 }], total: 1,
                             payments: [], paymentStatus: 'unpaid' }));

// What MongoDB does NOT enforce: a sale for a product that does not exist.
expectOk('T10 sale line pointing at a non-existent product IS accepted (no foreign keys), then removed',
  () => {
    db.sales.insertOne({ saleCode: 'TST-S4', saleDate: new Date(), customer: { customerId: 1, name: 'X' },
                         items: [{ productCode: 'NO-SUCH', quantity: 1, unitPrice: 1 }], total: 1,
                         payments: [], paymentStatus: 'unpaid' });
    db.sales.deleteOne({ saleCode: 'TST-S4' });
  });
