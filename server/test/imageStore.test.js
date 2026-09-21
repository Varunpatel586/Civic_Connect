/**
 * Cover for photograph storage: an upload is compressed into a bounded JPEG,
 * lands in GridFS, and streams back out byte-for-byte through the same
 * filename it was stored under. The HEIC-style fallback — an image the encoder
 * cannot read — must still be stored rather than rejected.
 *
 * GridFS is exercised against a real MongoDB, because chunking is exactly the
 * part a fake would lie about.
 */
const test = require('node:test');
const assert = require('node:assert/strict');

// config/env refuses to load without these; imageStore reads nothing else.
process.env.JWT_SECRET = 'test-secret-not-a-real-key';
process.env.MONGO_URI = 'mongodb://127.0.0.1:27017/unused';
process.env.API_URL = 'http://127.0.0.1';

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const sharp = require('sharp');

const imageStore = require('../services/imageStore');

let mongod;

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
    await mongoose.connect(mongod.getUri(), { dbName: 'imagestore_test' });
    available = true;
  } catch {
    available = false;
  }
});

test.after(async () => {
  if (mongoose.connection.readyState === 1) await mongoose.disconnect();
  if (mongod) await mongod.stop();
});

/** A photograph shaped like a phone camera's: large, and therefore the case
 * where compression decides whether Atlas M0 survives. */
async function phoneSizedJpeg() {
  return sharp({
    create: {
      width: 3024,
      height: 4032,
      channels: 3,
      background: { r: 40, g: 90, b: 140 },
    },
  })
    .jpeg({ quality: 95 })
    .toBuffer();
}

test('saves a phone-sized photograph as a small JPEG under a photo-*.jpg name', async (t) => {
  if (needsMongo(t)) return;

  const original = await phoneSizedJpeg();
  const stored = await imageStore.saveImage({
    buffer: original,
    originalname: 'IMG_2049.jpg',
    mimetype: 'image/jpeg',
  });

  assert.match(stored.filename, /^photo-\d+-\d+\.jpg$/);
  assert.equal(stored.compressed, true);
  // A flat image compresses hard; the guarantee being tested is order of
  // magnitude — hundreds of kilobytes at most, never megabytes.
  assert.ok(stored.bytes < 400 * 1024, `compressed to ${stored.bytes} bytes`);
  assert.ok(stored.bytes < original.length, 'smaller than the original upload');
});

test('streams the photograph back out with its content type intact', async (t) => {
  if (needsMongo(t)) return;

  const original = await phoneSizedJpeg();
  const { filename } = await imageStore.saveImage({
    buffer: original,
    originalname: 'IMG_2050.jpg',
    mimetype: 'image/jpeg',
  });

  const found = await imageStore.getImage(filename);
  assert.ok(found, 'file exists in GridFS');
  assert.equal(found.file.contentType, 'image/jpeg');
  assert.ok(found.file.length > 0);

  const chunks = [];
  for await (const chunk of found.stream) chunks.push(chunk);
  const bytes = Buffer.concat(chunks);

  assert.equal(bytes.length, found.file.length, 'stream length matches metadata');
  const roundTrip = await sharp(bytes).metadata();
  assert.equal(roundTrip.format, 'jpeg');
  // Longest edge is clamped to the compression width.
  assert.ok(Math.max(roundTrip.width, roundTrip.height) <= 1200);
});

test('stores undecodable uploads untouched rather than rejecting them', async (t) => {
  if (needsMongo(t)) return;

  // What arrives when the encoder has no HEIC support: opaque bytes with a
  // legitimate extension. The upload must survive.
  const opaque = Buffer.from([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]);

  const stored = await imageStore.saveImage({
    buffer: opaque,
    originalname: 'IMG_2051.heic',
    mimetype: 'image/heic',
  });

  assert.equal(stored.compressed, false);
  assert.match(stored.filename, /\.heic$/);

  const found = await imageStore.getImage(stored.filename);
  const chunks = [];
  for await (const chunk of found.stream) chunks.push(chunk);
  assert.deepEqual(Buffer.concat(chunks), opaque, 'original bytes preserved');
});

test('returns null for a filename that was never stored', async (t) => {
  if (needsMongo(t)) return;
  assert.equal(await imageStore.getImage('photo-0-0-never.jpg'), null);
});
