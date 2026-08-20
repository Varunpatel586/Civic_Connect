const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const express = require('express');

/**
 * Guards the Google sign-in route against regressing to what it used to do:
 * base64-decode the token body and trust whatever email it found, which let
 * anyone sign in as anyone.
 *
 * These cases all return before any database access, so no Mongo is needed.
 */
const startServer = async (env) => {
  // config/env.js refuses to load without these, by design.
  process.env.JWT_SECRET = 'test-secret-not-used-for-anything-real';
  process.env.MONGO_URI = 'mongodb://127.0.0.1:27017/civic_connect_test';

  for (const [key, value] of Object.entries(env)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }

  // Both read their configuration once at module load, so both caches go.
  delete require.cache[require.resolve('../config/env')];
  delete require.cache[require.resolve('../routes/auth')];
  const router = require('../routes/auth');

  const app = express();
  app.use(express.json());
  app.use('/api/auth', router);

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();

  return {
    post: async (path, body) => {
      const response = await fetch(`http://127.0.0.1:${port}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      const text = await response.text();
      let json = null;
      try {
        json = JSON.parse(text);
      } catch {
        json = { raw: text };
      }
      return { status: response.status, body: json };
    },
    close: () => new Promise((resolve) => server.close(resolve)),
  };
};

test('a missing token is rejected', async () => {
  const server = await startServer({ GOOGLE_CLIENT_IDS: 'test.apps.googleusercontent.com' });
  try {
    const { status } = await server.post('/api/auth/google', {});
    assert.equal(status, 400);
  } finally {
    await server.close();
  }
});

test('with no client IDs configured the route refuses instead of trusting', async () => {
  const server = await startServer({
    GOOGLE_CLIENT_IDS: undefined,
    GOOGLE_CLIENT_ID: undefined,
  });
  try {
    const { status, body } = await server.post('/api/auth/google', {
      idToken: 'anything at all',
    });

    assert.equal(status, 503);
    assert.match(body.message, /not configured/i);
    assert.equal(body.token, undefined, 'must never mint a session');
  } finally {
    await server.close();
  }
});

test('a forged token shaped like a real JWT is refused, not decoded', async () => {
  // This is the exact shape the old implementation accepted: a well-formed JWT
  // whose payload claims an arbitrary email. It carries no valid signature.
  const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ email: 'victim@example.com', email_verified: true, name: 'Victim' })
  ).toString('base64url');
  const forged = `${header}.${payload}.not-a-real-signature`;

  const server = await startServer({
    GOOGLE_CLIENT_IDS: undefined,
    GOOGLE_CLIENT_ID: undefined,
  });
  try {
    const { status, body } = await server.post('/api/auth/google', { idToken: forged });

    assert.notEqual(status, 200, 'a forged token must never produce a session');
    assert.equal(body.token, undefined);
  } finally {
    await server.close();
  }
});

test('a malformed token is refused when verification is configured', async () => {
  const server = await startServer({
    GOOGLE_CLIENT_IDS: 'test.apps.googleusercontent.com',
  });
  try {
    // Fails at parsing, so this never reaches the network.
    const { status, body } = await server.post('/api/auth/google', {
      idToken: 'not-a-jwt',
    });

    assert.equal(status, 401);
    assert.equal(body.token, undefined);
  } finally {
    await server.close();
  }
});
