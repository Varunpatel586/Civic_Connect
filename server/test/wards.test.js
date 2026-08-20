const test = require('node:test');
const assert = require('node:assert/strict');
const { wardFromAddress, officerCoversWard, wardFilter } = require('../config/wards');

test('reads the ward from a geocoded address', () => {
  assert.equal(
    wardFromAddress('Hill Road, Bandra West, 400050, Maharashtra, India'),
    'Bandra West'
  );
});

test('returns null when the address cannot supply one', () => {
  assert.equal(wardFromAddress('Hill Road'), null);
  assert.equal(wardFromAddress(''), null);
  assert.equal(wardFromAddress(null), null);
  assert.equal(wardFromAddress(undefined), null);
});

test('skips the literal "null" the geocoder emits for missing fields', () => {
  assert.equal(wardFromAddress('null, null, null'), null);
});

test('is not fooled by a non-string', () => {
  assert.equal(wardFromAddress(42), null);
  assert.equal(wardFromAddress({}), null);
});

test('an officer with no wards assigned covers everything', () => {
  assert.equal(officerCoversWard([], 'Bandra West'), true);
  assert.equal(officerCoversWard([], null), true);
  assert.equal(officerCoversWard(undefined, 'Anywhere'), true);
});

test('an assigned officer covers their own wards', () => {
  assert.equal(officerCoversWard(['Bandra West'], 'Bandra West'), true);
  assert.equal(officerCoversWard(['Bandra West', 'Andheri'], 'Andheri'), true);
});

test('an assigned officer is refused elsewhere', () => {
  assert.equal(officerCoversWard(['Bandra West'], 'Andheri'), false);
});

test('an assigned officer is refused on a complaint with no ward', () => {
  // Fail closed: an unlocatable complaint is not implicitly everyone's.
  assert.equal(officerCoversWard(['Bandra West'], null), false);
});

test('ward matching ignores case', () => {
  assert.equal(officerCoversWard(['bandra west'], 'Bandra West'), true);
});

test('an unassigned officer gets an unrestricted filter', () => {
  assert.deepEqual(wardFilter([]), {});
  assert.deepEqual(wardFilter(undefined), {});
});

test('an assigned officer gets a filter limited to their wards', () => {
  const filter = wardFilter(['Bandra West']);

  assert.ok(filter.ward);
  assert.ok(Array.isArray(filter.ward.$in));
  assert.equal(filter.ward.$in.length, 1);
  assert.ok(filter.ward.$in[0].test('bandra west'), 'should match case-insensitively');
  assert.ok(!filter.ward.$in[0].test('Andheri'));
});

test('ward names containing regex characters cannot break the filter', () => {
  // A ward literally named "St. Mary (North)" must not compile into a pattern
  // that matches something else.
  const filter = wardFilter(['St. Mary (North)']);

  assert.ok(filter.ward.$in[0].test('St. Mary (North)'));
  assert.ok(!filter.ward.$in[0].test('StXMary North'));
});
