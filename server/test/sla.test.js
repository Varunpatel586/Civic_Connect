const test = require('node:test');
const assert = require('node:assert/strict');
const sla = require('../config/sla');

const DAY = 86400000;
const now = new Date('2026-08-20T12:00:00Z');

const issue = ({ category = 'pothole', status = 'Pending', ageDays = 0 }) => ({
  category,
  status,
  createdAt: new Date(now.getTime() - ageDays * DAY),
});

test('urgent categories get a short response window', () => {
  assert.equal(sla.windowFor('water'), 2);
  assert.equal(sla.windowFor('electricity'), 2);
});

test('wear-and-tear categories get a long response window', () => {
  assert.equal(sla.windowFor('road'), 10);
  assert.equal(sla.windowFor('pothole'), 7);
});

test('an unknown category falls back instead of producing NaN', () => {
  assert.equal(sla.windowFor('meteor_strike'), sla.DEFAULT_WINDOW_DAYS);
  assert.equal(sla.windowFor(undefined), sla.DEFAULT_WINDOW_DAYS);
  assert.equal(sla.windowFor(null), sla.DEFAULT_WINDOW_DAYS);
});

test('category matching ignores case', () => {
  assert.equal(sla.windowFor('WATER'), 2);
});

test('the deadline is the filing date plus the window', () => {
  const due = sla.dueDate(issue({ category: 'water', ageDays: 0 }));
  assert.equal(due.getTime(), now.getTime() + 2 * DAY);
});

test('work inside its window is not overdue', () => {
  assert.equal(sla.isOverdue(issue({ category: 'pothole', ageDays: 3 }), now), false);
});

test('work past its window is overdue', () => {
  assert.equal(sla.isOverdue(issue({ category: 'water', ageDays: 5 }), now), true);
});

test('closed work is never overdue, however old', () => {
  const ancient = { category: 'water', ageDays: 900 };
  assert.equal(
    sla.isOverdue(issue({ ...ancient, status: 'Resolved' }), now),
    false
  );
  assert.equal(
    sla.isOverdue(issue({ ...ancient, status: 'Rejected' }), now),
    false
  );
});

test('isClosed recognises exactly the terminal states', () => {
  assert.equal(sla.isClosed({ status: 'Resolved' }), true);
  assert.equal(sla.isClosed({ status: 'Rejected' }), true);
  assert.equal(sla.isClosed({ status: 'Pending' }), false);
  assert.equal(sla.isClosed({ status: 'In Progress' }), false);
});

test('the policy table matches the client fallback in lib/utils/sla.dart', () => {
  // Guards the one duplication in the codebase. If this fails, the citizen app
  // and the municipal dashboard disagree about what is late.
  assert.deepEqual(sla.WINDOW_DAYS, {
    water: 2,
    electricity: 2,
    street_light: 3,
    garbage: 3,
    drainage: 5,
    pothole: 7,
    road: 10,
    other: 7,
  });
});
