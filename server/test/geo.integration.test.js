const test = require('node:test');
const assert = require('node:assert/strict');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const Issue = require('../models/Issue');
const { backfillIssues } = require('../config/backfill');
const { wardFilter } = require('../config/wards');

const EARTH_RADIUS_KM = 6378.1;

/** Mirrors the query in GET /api/issues/nearby. */
const within = (lng, lat, radiusKm) =>
  Issue.find({
    location: {
      $geoWithin: { $centerSphere: [[lng, lat], radiusKm / EARTH_RADIUS_KM] },
    },
  })
    .sort({ createdAt: -1 })
    .lean();

// Bandra West, and a landmark ~19 km away across the city.
const BANDRA = { lat: 19.0596, lng: 72.8295 };
const POWAI = { lat: 19.1176, lng: 72.906 };

let mongod;

/**
 * These tests need a real MongoDB. `mongodb-memory-server` fetches one on first
 * run, which needs network access — so an unavailable binary skips rather than
 * fails. A test suite that goes red on a train is a test suite people stop
 * running.
 */
let available = false;
const needsMongo = (t) => {
  if (!available) {
    t.skip('MongoDB unavailable (mongodb-memory-server could not start)');
    return true;
  }
  return false;
};

const seedIssue = (overrides = {}) =>
  new Issue({
    userId: new mongoose.Types.ObjectId(),
    title: 'Test complaint',
    category: 'pothole',
    imageUrl: 'http://example.test/a.jpg',
    latitude: BANDRA.lat,
    longitude: BANDRA.lng,
    address: 'Hill Road, Bandra West, 400050, Maharashtra, India',
    ...overrides,
  }).save();

test.before(async () => {
  try {
    mongod = await MongoMemoryServer.create();
    await mongoose.connect(mongod.getUri(), { dbName: 'civic_connect_test' });
    // Geo queries need the index to exist, which `syncIndexes` guarantees here
    // the way the server's own index build does in production.
    await Issue.syncIndexes();
    available = true;
  } catch (error) {
    console.warn(`Skipping geo integration tests: ${error.message}`);
  }
});

test.after(async () => {
  if (!available) return;
  await mongoose.disconnect();
  await mongod.stop();
});

test.beforeEach(async () => {
  if (available) await Issue.deleteMany({});
});

test('saving derives the GeoJSON point and the ward', async (t) => {
  if (needsMongo(t)) return;

  const issue = await seedIssue();

  assert.deepEqual(issue.location.coordinates, [BANDRA.lng, BANDRA.lat]);
  assert.equal(issue.ward, 'Bandra West');
});

test('a nearby complaint is returned', async (t) => {
  if (needsMongo(t)) return;

  await seedIssue();

  const found = await within(BANDRA.lng, BANDRA.lat, 5);

  assert.equal(found.length, 1);
});

test('a complaint outside the radius is excluded', async (t) => {
  if (needsMongo(t)) return;

  await seedIssue({ latitude: POWAI.lat, longitude: POWAI.lng });

  const near = await within(BANDRA.lng, BANDRA.lat, 5);
  const wide = await within(BANDRA.lng, BANDRA.lat, 30);

  assert.equal(near.length, 0, 'Powai is well beyond 5 km of Bandra');
  assert.equal(wide.length, 1, 'and well inside 30 km');
});

test('the unbounded radius the feed uses returns everything', async (t) => {
  if (needsMongo(t)) return;

  await seedIssue();
  await seedIssue({ latitude: POWAI.lat, longitude: POWAI.lng });
  // A complaint on the far side of the planet.
  await seedIssue({ latitude: -33.8688, longitude: 151.2093, address: 'George St, Sydney' });

  const all = await within(0, 0, 20000);

  assert.equal(all.length, 3);
});

test('results come back newest first', async (t) => {
  if (needsMongo(t)) return;

  const old = await seedIssue({ title: 'Older' });
  const recent = await seedIssue({ title: 'Newer' });

  await Issue.updateOne({ _id: old._id }, { $set: { createdAt: new Date('2020-01-01') } });
  await Issue.updateOne({ _id: recent._id }, { $set: { createdAt: new Date('2026-01-01') } });

  const found = await within(BANDRA.lng, BANDRA.lat, 5);

  assert.deepEqual(found.map((i) => i.title), ['Newer', 'Older']);
});

test('a legacy document with no location is invisible until backfilled', async (t) => {
  if (needsMongo(t)) return;

  // Exactly the shape written before the geo field existed: inserted straight
  // through the driver so the schema hook cannot fill it in.
  await mongoose.connection.collection('issues').insertOne({
    userId: new mongoose.Types.ObjectId(),
    title: 'Legacy complaint',
    category: 'pothole',
    imageUrl: 'http://example.test/legacy.jpg',
    imageUrls: [],
    latitude: BANDRA.lat,
    longitude: BANDRA.lng,
    address: 'Hill Road, Bandra West, 400050, Maharashtra, India',
    status: 'Pending',
    agreeCount: 0,
    disagreeCount: 0,
    statusHistory: [],
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  const before = await within(BANDRA.lng, BANDRA.lat, 5);
  assert.equal(before.length, 0, 'this is the silent data loss the backfill exists to prevent');

  const result = await backfillIssues({ log: () => {} });
  assert.equal(result.location, 1);
  assert.equal(result.ward, 1);

  const after = await within(BANDRA.lng, BANDRA.lat, 5);
  assert.equal(after.length, 1);
  assert.equal(after[0].ward, 'Bandra West');
});

test('the backfill is idempotent', async (t) => {
  if (needsMongo(t)) return;

  await seedIssue();

  const first = await backfillIssues({ log: () => {} });
  const second = await backfillIssues({ log: () => {} });

  assert.deepEqual(first, { location: 0, ward: 0 }, 'a current document needs nothing');
  assert.deepEqual(second, { location: 0, ward: 0 });
});

test('the ward filter scopes an officer to their own ward', async (t) => {
  if (needsMongo(t)) return;

  await seedIssue({ address: 'Hill Road, Bandra West, 400050, Maharashtra, India' });
  await seedIssue({ address: 'Central Ave, Andheri, 400053, Maharashtra, India' });

  const scoped = await Issue.find(wardFilter(['Bandra West'])).lean();
  const unscoped = await Issue.find(wardFilter([])).lean();

  assert.equal(scoped.length, 1);
  assert.equal(scoped[0].ward, 'Bandra West');
  assert.equal(unscoped.length, 2, 'no assignment means every ward');
});

test('ward scoping is case-insensitive', async (t) => {
  if (needsMongo(t)) return;

  await seedIssue({ address: 'Hill Road, Bandra West, 400050, Maharashtra, India' });

  const found = await Issue.find(wardFilter(['bandra west'])).lean();

  assert.equal(found.length, 1);
});
