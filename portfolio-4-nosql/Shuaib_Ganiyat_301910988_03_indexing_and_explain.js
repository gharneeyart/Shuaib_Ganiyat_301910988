// Portfolio 4: index evidence with explain(), the MongoDB counterpart of Portfolio 2.
// Run:  mongosh "$MONGODB_URI" --file Shuaib_Ganiyat_301910988_03_indexing_and_explain.js
// Run Shuaib_Ganiyat_301910988_01_setup_and_seed.js first. The script adds 20,000 SYNTHETIC inventory
// events so the difference is measurable, then deletes them again at the end.

db = db.getSiblingDB('adetwin_stores_nosql');
const codes = ['GR-001', 'GR-002', 'CE-001', 'CE-002', 'BV-001', 'HH-001'];

// 1. Synthetic load (clearly marked: reference = 'SYNTHETIC').
const batch = [];
for (let i = 0; i < 20000; i++) {
  batch.push({ productCode: codes[i % codes.length], eventType: 'sale', quantityChange: -1,
               eventDate: new Date(Date.UTC(2026, 0, 1) + i * 600000), reference: 'SYNTHETIC' });
}
db.inventoryEvents.insertMany(batch);
print('inventoryEvents now holds ' + db.inventoryEvents.countDocuments() + ' documents');

// Query: the 20 newest events of one product (same idea as Q7 in Portfolio 2).
const run = (label) => {
  const e = db.inventoryEvents.find({ productCode: 'GR-001' }).sort({ eventDate: -1 }).limit(20)
              .explain('executionStats');
  print('\n=== ' + label);
  print('nReturned: ' + e.executionStats.nReturned +
        ' | totalDocsExamined: ' + e.executionStats.totalDocsExamined +
        ' | totalKeysExamined: ' + e.executionStats.totalKeysExamined +
        ' | executionTimeMillis: ' + e.executionStats.executionTimeMillis);
  printjson(e.queryPlanner.winningPlan);   // look for COLLSCAN (whole collection) or IXSCAN (index)
};

// 2. BEFORE: only the default _id index exists on this collection.
print('\nIndexes before:'); printjson(db.inventoryEvents.getIndexes().map(i => i.name));
run('BEFORE the index');

// 3. Compound index: equality field first, sort field second (same rule as PostgreSQL).
db.inventoryEvents.createIndex({ productCode: 1, eventDate: -1 });

print('\nIndexes after:'); printjson(db.inventoryEvents.getIndexes().map(i => i.name));
run('AFTER the index');

// 5. Clean up the synthetic data (keeps the sample data consistent with the products).
printjson(db.inventoryEvents.deleteMany({ reference: 'SYNTHETIC' }));
print('inventoryEvents back to ' + db.inventoryEvents.countDocuments() + ' documents');

// 6. Index list of the other collections, for the evidence screenshot.
print('\nproducts indexes:');  printjson(db.products.getIndexes().map(i => i.name));
print('sales indexes:');       printjson(db.sales.getIndexes().map(i => i.name));
