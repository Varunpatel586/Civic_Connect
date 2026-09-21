/**
 * Cover for the photograph-serving route: bytes come back out of GridFS under
 * the same URL the client was given, files that predate the migration are
 * still served from disk, and a crafted filename cannot escape the uploads
 * directory.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

process.env.JWT_SECRET = 'test-secret-not-a-real-key';
process.env.MONGO_URI = 'mongodb://127.0.0.1:27017/unused';
process.env.API_URL = 'http://127.0.0.1';

const mongoose = require('mongoose');
const express = require('express');
const sharp = require('sharp');
const { MongoMemoryServer } = require('mongodb-memory-server');

const imageStore = require('../services/imageStore');
const uploadsRouter = require('../routes/uploads');

let mongod;
let server;
let baseUrl;

let available = false;
const needsMongo = (t) => {
  if (!available) {
    t.skip('MongoDB unavailable (mongodb-memory-server could not start)');
    return true;
  }
  return false;
};

test.before(async () => {
  try {
    mongod = await MongoMemoryServer.create();
    await mongoose.connect(mongod.getUri(), { dbName: 'uploads_route_test' });
  } catch {
    available = false;
    return;
  }

  const app = express();
  app.use('/uploads', uploadsRouter);
  server = app.listen(0);
  baseUrl = `http://127.0.0.1:${server.address().port}`;
  available = true;
});

test.after(async () => {
  if (server) await new Promise((resolve) => server.close(resolve));
  if (mongoose.connection.readyState === 1) await mongoose.disconnect();
  if (mongod) await mongod.stop();
});

const tinyJpeg = () =>
  sharp({ create: { width: 600, height: 400, channels: 3, background: { r: 10, g: 60, b: 120 } } })
    .jpeg({ quality: 70 })
    .toBuffer();

test('serves a GridFS photograph with its content type and cache headers', async (t) => {
  if (needsMongo(t)) return;

  const bytes = await tinyJpeg();
  const { filename } = await imageStore.saveImage({
    buffer: bytes,
    originalname: 'IMG_1.jpg',
    mimetype: 'image/jpeg',
  });

  const res = await fetch(`${baseUrl}/uploads/${filename}`);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('content-type'), 'image/jpeg');
  assert.equal(res.headers.get('cache-control'), 'public, max-age=2592000, immutable');
  assert.equal(res.headers.get('x-content-type-options'), 'nosniff');
  assert.equal(res.headers.get('content-disposition'), 'inline');
  assert.equal(Number(res.headers.get('content-length')), (await res.arrayBuffer()).byteLength);
});

test('still serves photographs that only exist in the legacy directory', async (t) => {
  if (needsMongo(t)) return;

  // Uses whatever the repository happens to carry in server/uploads (the seed
  // images). Skipped on a checkout with an empty directory rather than failing.
  const legacyDir = path.join(__dirname, '../uploads');
  const legacyFile = fs.existsSync(legacyDir)
    ? fs.readdirSync(legacyDir).find((name) => !name.startsWith('.'))
    : undefined;
  if (!legacyFile) return t.skip('No legacy upload files present in server/uploads');

  const res = await fetch(`${baseUrl}/uploads/${encodeURIComponent(legacyFile)}`);
  assert.equal(res.status, 200);
  assert.ok((await res.arrayBuffer()).byteLength > 0);
});

test('answers 404 for a filename that exists in neither store', async (t) => {
  if (needsMongo(t)) return;
  const res = await fetch(`${baseUrl}/uploads/photo-1-1-never.jpg`);
  assert.equal(res.status, 404);
});

test('refuses a crafted filename that would escape the uploads directory', async (t) => {
  if (needsMongo(t)) return;
  const res = await fetch(`${baseUrl}/uploads/..%2fserver.js`);
  assert.equal(res.status, 404);
});
