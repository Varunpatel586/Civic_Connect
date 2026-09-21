/**
 * Cover for stored-URL rewriting: URLs that point into /uploads/ must be
 * rebuilt against the API host actually serving this deployment, because the
 * host that uploaded a photograph is not necessarily the host serving it now.
 * Everything else — Google avatars, stock photographs, empty values — passes
 * through untouched.
 */
const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = 'test-secret-not-a-real-key';
process.env.MONGO_URI = 'mongodb://127.0.0.1:27017/unused';
process.env.API_URL = 'https://civic-connect-api.example.onrender.com';

const absoluteStoredUrl = require('../utils/absoluteStoredUrl');

test('rebuilds a localhost upload URL against the configured API host', () => {
  assert.equal(
    absoluteStoredUrl('http://localhost:5000/uploads/photo-1787250320905-618967136.jpg'),
    'https://civic-connect-api.example.onrender.com/uploads/photo-1787250320905-618967136.jpg'
  );
});

test('rebuilds upload URLs from any previous deployment host', () => {
  assert.equal(
    absoluteStoredUrl('https://civic-connect-api-eq0j.onrender.com/uploads/pothole_2.jpg'),
    'https://civic-connect-api.example.onrender.com/uploads/pothole_2.jpg'
  );
});

test('rewrites relative upload paths too', () => {
  assert.equal(
    absoluteStoredUrl('/uploads/photo-1-2.jpg'),
    'https://civic-connect-api.example.onrender.com/uploads/photo-1-2.jpg'
  );
});

test('keeps external image URLs exactly as stored', () => {
  const external =
    'https://plus.unsplash.com/premium_photo-1663036928694?fm=jpg&q=60&w=3000';
  assert.equal(absoluteStoredUrl(external), external);
  const avatar = 'https://lh3.googleusercontent.com/a/ACg8ocK=user';
  assert.equal(absoluteStoredUrl(avatar), avatar);
});

test('passes null, empty strings and non-strings through', () => {
  assert.equal(absoluteStoredUrl(null), null);
  assert.equal(absoluteStoredUrl(''), '');
  assert.equal(absoluteStoredUrl(undefined), undefined);
  assert.equal(absoluteStoredUrl(42), 42);
});
