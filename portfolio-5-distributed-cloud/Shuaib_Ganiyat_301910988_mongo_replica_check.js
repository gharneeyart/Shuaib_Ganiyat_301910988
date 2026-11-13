// Portfolio 5: replication and consistency checks on MongoDB.
// Run:  mongosh "$MONGODB_URI" --file Shuaib_Ganiyat_301910988_mongo_replica_check.js
// A MongoDB Atlas cluster (including the free M0 tier) is a replica set of 3 nodes.
// This script shows that, then compares two write guarantees. It creates one
// scratch collection (wc_demo) and drops it at the end.

db = db.getSiblingDB('adetwin_stores_nosql');

// 1. Replica set membership.
const h = db.hello();
print('Replica set name : ' + h.setName);
print('Primary          : ' + h.primary);
print('Connected to     : ' + h.me + (h.isWritablePrimary ? '  (this node is the PRIMARY)' : '  (this node is a secondary)'));
print('All members      : ' + JSON.stringify(h.hosts));
print('Member count     : ' + h.hosts.length);

// 2. Optional detail. rs.status() may be restricted on shared tiers; that is fine.
try {
  rs.status().members.forEach(m => print(m.name + '  ' + m.stateStr));
} catch (e) {
  print('rs.status() not permitted on this tier: ' + e.message);
}

// 3. Write concern: how many nodes must confirm before the write counts as done?
//    w:1        = only the primary confirms (fast, but lost if the primary fails before replicating)
//    w:majority = a majority of nodes confirm (slower, survives a primary failure)
const N = 50;
const timeWrites = (wc) => {
  const t0 = Date.now();
  for (let i = 0; i < N; i++) {
    db.wc_demo.insertOne({ n: i, wc: String(wc.w), at: new Date() }, { writeConcern: wc });
  }
  return (Date.now() - t0) / N;
};
const w1  = timeWrites({ w: 1 });
const wmj = timeWrites({ w: 'majority' });
print('\nAverage time per insert over ' + N + ' writes:');
print('  w:1        = ' + w1.toFixed(1)  + ' ms');
print('  w:majority = ' + wmj.toFixed(1) + ' ms');

// 4. Read preference: which node answered?
//    explain() reports the host that executed the query.
const hostOf = (mode) => {
  try { return db.products.find().readPref(mode).explain('queryPlanner').serverInfo.host; }
  catch (e) { return 'n/a (' + e.message + ')'; }
};
print('\nRead served by (readPreference primary)  : ' + hostOf('primary'));
print('Read served by (readPreference secondary): ' + hostOf('secondary'));
print('If the second host differs from the primary, the read came from a secondary,');
print('which may lag slightly behind the primary (eventual consistency).');

db.wc_demo.drop();
print('\nScratch collection dropped.');
