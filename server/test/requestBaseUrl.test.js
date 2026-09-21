const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  requestBaseUrl,
  withRequestBaseUrl,
  currentRequestBaseUrl,
} = require('../utils/requestBaseUrl');

/** Minimal request double exposing the headers Express would provide. */
const req = ({ host, proto = 'http', forwardedProto, forwardedHost }) => ({
  headers: {
    ...(forwardedHost ? { 'x-forwarded-host': forwardedHost } : {}),
    ...(forwardedProto ? { 'x-forwarded-proto': forwardedProto } : {}),
  },
  get: (name) => (name === 'host' ? host : undefined),
  protocol: proto,
});

/** Runs `next` the way Express would, through the real middleware. */
const through = (request, fn) =>
  new Promise((resolve, reject) => {
    withRequestBaseUrl(request, {}, () => {
      try {
        resolve(fn());
      } catch (err) {
        reject(err);
      }
    });
  });

describe('requestBaseUrl', () => {
  it('reads the ordinary case', () => {
    assert.equal(
      requestBaseUrl(req({ host: 'localhost:5000' })),
      'http://localhost:5000',
    );
  });

  it('prefers the forwarded protocol, because TLS ends before the app', () => {
    // Render's proxy terminates TLS, so the socket is plain http. Trusting
    // req.protocol alone would hand Android an http:// photograph URL, which it
    // refuses outright as cleartext.
    assert.equal(
      requestBaseUrl(
        req({ host: 'civic-connect-api-eq0j.onrender.com', forwardedProto: 'https' }),
      ),
      'https://civic-connect-api-eq0j.onrender.com',
    );
  });

  it('takes only the first value of a chained forwarded protocol header', () => {
    assert.equal(
      requestBaseUrl(req({ host: 'example.com', forwardedProto: 'https, http' })),
      'https://example.com',
    );
  });

  it('prefers the forwarded host, which is the name the client typed', () => {
    assert.equal(
      requestBaseUrl(
        req({ host: 'internal-abc:10000', forwardedHost: 'civic-connect-api-eq0j.onrender.com' }),
      ),
      'http://civic-connect-api-eq0j.onrender.com',
    );
  });

  it('returns null when there is no Host to build from', () => {
    assert.equal(requestBaseUrl(req({ host: undefined })), null);
  });
});

describe('withRequestBaseUrl', () => {
  it('publishes the origin for the duration of the request', async () => {
    const seen = await through(req({ host: 'example.com:5000', forwardedProto: 'https' }), () =>
      currentRequestBaseUrl(),
    );

    assert.equal(seen, 'https://example.com:5000');
  });

  it('leaks nothing outside the request it belongs to', async () => {
    await through(req({ host: 'first.example' }), () => currentRequestBaseUrl());
    assert.equal(currentRequestBaseUrl(), null);
  });

  it('keeps concurrent requests from seeing each other', async () => {
    const [a, b] = await Promise.all([
      through(req({ host: 'a.example' }), async () => {
        await new Promise((resolve) => setTimeout(resolve, 10));
        return currentRequestBaseUrl();
      }),
      through(req({ host: 'b.example' }), async () => {
        await new Promise((resolve) => setTimeout(resolve, 1));
        return currentRequestBaseUrl();
      }),
    ]);

    assert.equal(a, 'http://a.example');
    assert.equal(b, 'http://b.example');
  });

  it('declines to set a context when the request has no Host', async () => {
    const seen = await through(req({ host: undefined }), () => currentRequestBaseUrl());
    assert.equal(seen, null);
  });
});
