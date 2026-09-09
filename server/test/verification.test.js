/**
 * End-to-end cover for the closed loop: an officer claims a fix, the reporters
 * are told, and their answer either closes the complaint for good or sends it
 * back into the queue escalated.
 *
 * Push is deliberately not configured here. The inbox rows are asserted
 * directly, which is the guarantee the design actually rests on — a message is
 * durable before any push is attempted, so the loop closes with or without FCM.
 */
const test = require('node:test');
const assert = require('node:assert/strict');

// config/env refuses to load without these, and the middleware signs with the
// secret. The URI is never dialled — the in-memory server's URI is used for the
// real connection below — but config/env demands one be present.
process.env.JWT_SECRET = 'test-secret-not-a-real-key';
process.env.MONGO_URI = 'mongodb://127.0.0.1:27017/unused';
process.env.API_URL = 'http://127.0.0.1';

const mongoose = require('mongoose');
const express = require('express');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

const Issue = require('../models/Issue');
const User = require('../models/User');
const Notification = require('../models/Notification');
const verification = require('../services/verification');

let mongod;
let server;
let baseUrl;

/**
 * Same contract as the other integration suites here: an unavailable Mongo
 * binary skips rather than fails, because a suite that goes red on a train is
 * a suite people stop running.
 */
let available = false;
const needsMongo = (t) => {
  if (!available) {
    t.skip('MongoDB unavailable (mongodb-memory-server could not start)');
    return true;
  }
  return false;
};

const tokenFor = (user) =>
  jwt.sign(
    { user: { id: user._id.toString(), role: user.role } },
    process.env.JWT_SECRET
  );

async function api(pathname, { method = 'GET', token, body } = {}) {
  const res = await fetch(baseUrl + pathname, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: 'Bearer ' + token } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

test.before(async () => {
  try {
    mongod = await MongoMemoryServer.create();
    await mongoose.connect(mongod.getUri(), { dbName: 'civic_connect_test' });

    // Mounted directly rather than importing server.js, which would open a
    // real port and dial the configured Atlas cluster.
    const app = express();
    app.use(express.json());
    app.use('/api/issues', require('../routes/issues'));
    app.use('/api/notifications', require('../routes/notifications'));

    await new Promise((resolve) => {
      server = app.listen(0, () => {
        baseUrl = 'http://127.0.0.1:' + server.address().port;
        resolve();
      });
    });

    available = true;
  } catch (error) {
    console.warn(`Skipping verification tests: ${error.message}`);
  }
});

test.after(async () => {
  if (!available) return;
  await new Promise((r) => server.close(r));
  await mongoose.disconnect();
  await mongod.stop();
});

/** Fresh cast per test, so cases cannot leak into one another. */
async function seed() {
  await Promise.all([
    Issue.deleteMany({}),
    User.deleteMany({}),
    Notification.deleteMany({}),
  ]);

  const [reporterA, reporterB, officer, stranger] = await User.create([
    { username: 'reporter_a', email: 'a@test.dev', password: 'x' },
    { username: 'reporter_b', email: 'b@test.dev', password: 'x' },
    { username: 'officer', email: 'o@test.dev', password: 'x', role: 'admin' },
    { username: 'stranger', email: 's@test.dev', password: 'x' },
  ]);

  // Two reporters, because clustering means one complaint can carry several.
  const issue = await Issue.create({
    userId: reporterA._id,
    reporters: [reporterA._id, reporterB._id],
    title: 'Pothole on MG Road',
    category: 'pothole',
    description: 'Deep pothole',
    imageUrl: 'http://example.test/a.jpg',
    imageUrls: ['http://example.test/a.jpg'],
    latitude: 23.02,
    longitude: 72.57,
    address: 'MG Road, Ahmedabad, 380001, Gujarat, India',
  });

  return { reporterA, reporterB, officer, stranger, issue };
}

const PROOF_PHOTO = 'http://example.test/work-completed.jpg';

const resolveAs = (officer, issue, note) =>
  api('/api/issues/' + issue._id + '/status', {
    method: 'PATCH',
    token: tokenFor(officer),
    body: {
      status: 'Resolved',
      photo_url: PROOF_PHOTO,
      ...(note ? { note } : {}),
    },
  });

test('resolving opens a verification window and notifies every reporter', async (t) => {
  if (needsMongo(t)) return;
  const { reporterA, reporterB, officer, issue } = await seed();

  const res = await resolveAs(officer, issue, 'Filled it');

  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'Resolved');
  assert.equal(res.body.verification_state, 'pending');
  assert.ok(res.body.verification_due_by, 'a deadline is set');
  assert.match(res.body.reference, /^CC-\d{4}-GJ-\d{5}$/);

  // The proof photo comes back on the entry and as the top-level convenience
  // field the citizen's before/after comparison reads.
  assert.equal(res.body.resolution_photo_url, PROOF_PHOTO);
  const resolvedEntry = res.body.status_history.at(-1);
  assert.equal(resolvedEntry.status, 'Resolved');
  assert.equal(resolvedEntry.photo_url, PROOF_PHOTO);

  // Both reporters are told, not just the original filer.
  const inbox = await Notification.find({}).lean();
  assert.equal(inbox.length, 2);
  assert.deepEqual(
    inbox.map((n) => n.userId.toString()).sort(),
    [reporterA._id.toString(), reporterB._id.toString()].sort()
  );
  assert.equal(inbox[0].type, 'verification_requested');
});

test('an officer cannot claim a fix without showing it', async (t) => {
  if (needsMongo(t)) return;
  const { officer, issue } = await seed();

  const res = await api('/api/issues/' + issue._id + '/status', {
    method: 'PATCH',
    token: tokenFor(officer),
    body: { status: 'Resolved', note: 'Trust me' },
  });

  assert.equal(res.status, 400);
  assert.match(res.body.message, /photo/i);

  // Nothing was written: the complaint is untouched and no one was notified.
  const after = await Issue.findById(issue._id).lean();
  assert.equal(after.status, 'Pending');
  assert.equal(after.verification.state, 'none');
  assert.equal(await Notification.countDocuments({}), 0);
});

test('rejecting needs no photo — there is nothing to photograph', async (t) => {
  if (needsMongo(t)) return;
  const { officer, issue } = await seed();

  const res = await api('/api/issues/' + issue._id + '/status', {
    method: 'PATCH',
    token: tokenFor(officer),
    body: { status: 'Rejected', note: 'Outside municipal remit' },
  });

  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'Rejected');
  assert.equal(res.body.verification_state, 'none');
});

test('a disputed fix reopens the complaint, escalates it, and tells the officer', async (t) => {
  if (needsMongo(t)) return;
  const { reporterA, officer, issue } = await seed();

  await resolveAs(officer, issue, 'Filled it');
  await Notification.deleteMany({});

  const res = await api('/api/issues/' + issue._id + '/verify', {
    method: 'POST',
    token: tokenFor(reporterA),
    body: {
      confirmed: false,
      note: 'Still there',
      evidence_url: 'http://example.test/still-broken.jpg',
    },
  });

  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'In Progress', 'goes back into the queue');
  assert.equal(res.body.verification_state, 'disputed');
  assert.equal(res.body.reopen_count, 1);
  assert.ok(res.body.escalated_at, 'escalation is stamped');
  assert.equal(res.body.closed_at, null, 'closure is undone');

  const forOfficer = await Notification.find({ userId: officer._id }).lean();
  assert.equal(forOfficer.length, 1);
  assert.equal(forOfficer[0].type, 'verification_disputed');
});

test('a confirmed fix closes the complaint for good', async (t) => {
  if (needsMongo(t)) return;
  const { reporterB, officer, issue } = await seed();

  await resolveAs(officer, issue);

  const res = await api('/api/issues/' + issue._id + '/verify', {
    method: 'POST',
    token: tokenFor(reporterB),
    body: { confirmed: true },
  });

  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'Resolved');
  assert.equal(res.body.verification_state, 'confirmed');
  assert.ok(res.body.closed_at, 'closure stands');
  assert.equal(res.body.reopen_count, 0);
});

test('only the people who reported it may verify the fix', async (t) => {
  if (needsMongo(t)) return;
  const { stranger, officer, issue } = await seed();

  await resolveAs(officer, issue);

  const res = await api('/api/issues/' + issue._id + '/verify', {
    method: 'POST',
    token: tokenFor(stranger),
    body: { confirmed: false },
  });

  assert.equal(res.status, 403);
});

test('verifying a complaint nobody was asked about is rejected', async (t) => {
  if (needsMongo(t)) return;
  const { reporterA, issue } = await seed();

  const res = await api('/api/issues/' + issue._id + '/verify', {
    method: 'POST',
    token: tokenFor(reporterA),
    body: { confirmed: true },
  });

  assert.equal(res.status, 409);
  assert.equal(res.body.state, 'none');
});

test('silence past the deadline settles as auto-confirmed', async (t) => {
  if (needsMongo(t)) return;
  const { officer, issue } = await seed();

  await resolveAs(officer, issue);

  // Wind the deadline back rather than waiting seventy-two hours.
  await Issue.updateOne(
    { _id: issue._id },
    { $set: { 'verification.dueBy': new Date(Date.now() - 1000) } }
  );

  assert.equal(await verification.settleExpired(), 1);

  const after = await Issue.findById(issue._id).lean();
  assert.equal(after.verification.state, 'auto_confirmed');
});

test('moving off Resolved before anyone answers drops the question', async (t) => {
  if (needsMongo(t)) return;
  const { officer, issue } = await seed();

  await resolveAs(officer, issue);
  const res = await api('/api/issues/' + issue._id + '/status', {
    method: 'PATCH',
    token: tokenFor(officer),
    body: { status: 'In Progress', note: 'Reopened by the office' },
  });

  assert.equal(res.status, 200);
  assert.equal(res.body.verification_state, 'none');
  assert.equal(res.body.verification_due_by, null);
});
