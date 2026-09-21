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

/**
 * `absoluteStoredUrl` doubles as an Array.map callback, which passes the element
 * index as the second argument. If that index were treated as an origin, every
 * photograph after the first would resolve to a host like "1" — so this is the
 * guard that keeps `.map(absoluteStoredUrl)` safe.
 */
test('ignores a non-string second argument, as Array.map supplies', () => {
  assert.equal(
    absoluteStoredUrl('http://localhost:5000/uploads/photo-1.jpg', 3),
    'https://civic-connect-api.example.onrender.com/uploads/photo-1.jpg'
  );
});

test('accepts an explicit origin, overriding the configured one', () => {
  assert.equal(
    absoluteStoredUrl('http://localhost:5000/uploads/photo-1.jpg', 'https://served-from.example'),
    'https://served-from.example/uploads/photo-1.jpg'
  );
});

test('tolerates a trailing slash on the supplied origin', () => {
  assert.equal(
    absoluteStoredUrl('http://localhost:5000/uploads/photo-1.jpg', 'https://served-from.example/'),
    'https://served-from.example/uploads/photo-1.jpg'
  );
});

/**
 * The request's own origin outranks configuration, which is the whole point:
 * Render hands out an unpredictable hostname suffix, so a hand-typed API_URL
 * that disagrees with reality would otherwise produce links to a host that does
 * not exist. This is the bug that left photographs blank in the deployed app.
 */
test('prefers the origin of the request being answered', () => {
  const { withRequestBaseUrl } = require('../utils/requestBaseUrl');

  const req = {
    headers: { 'x-forwarded-proto': 'https' },
    get: (name) => (name === 'host' ? 'civic-connect-api-eq0j.onrender.com' : undefined),
    protocol: 'http',
  };

  withRequestBaseUrl(req, {}, () => {
    assert.equal(
      absoluteStoredUrl('http://localhost:5000/uploads/photo-1.jpg'),
      'https://civic-connect-api-eq0j.onrender.com/uploads/photo-1.jpg'
    );
  });
});

/**
 * Outside a request — a background job, a migration script — there is no origin
 * to observe, so RENDER_EXTERNAL_URL, which Render injects, is more trustworthy
 * than a hand-typed API_URL. Checked in a child process because the value is
 * read once when the config module loads.
 */
test('falls back to RENDER_EXTERNAL_URL when nothing is serving a request', () => {
  const { execFileSync } = require('node:child_process');
  const script = `
    process.env.JWT_SECRET = 'test-secret-not-a-real-key';
    process.env.MONGO_URI = 'mongodb://127.0.0.1:27017/unused';
    process.env.API_URL = 'https://stale-guess.example';
    process.env.RENDER_EXTERNAL_URL = 'https://civic-connect-api-eq0j.onrender.com';
    const url = require('${require('node:path').resolve(__dirname, '../utils/absoluteStoredUrl').replace(/\\/g, '/')}');
    process.stdout.write(url('http://localhost:5000/uploads/photo-1.jpg'));
  `;

  const out = execFileSync(process.execPath, ['-e', script], { encoding: 'utf8' });
  assert.equal(out, 'https://civic-connect-api-eq0j.onrender.com/uploads/photo-1.jpg');
});
