/**
 * One-off migration: photographs on disk in `server/uploads` into MongoDB
 * GridFS, compressed on the way in.
 *
 * Each file keeps its exact filename, so every URL already stored in an issue
 * document — `…/uploads/pothole_2.jpg`, `…/uploads/photo-1787250….jpg` — keeps
 * resolving through the `/uploads/:filename` route with no document rewrite.
 *
 * Idempotent: a file that already exists in GridFS under that name is skipped,
 * so the script can be re-run after an interrupted pass.
 *
 * Usage:
 *   node scripts/migrateUploadsToGridFS.js          # migrate
 *   node scripts/migrateUploadsToGridFS.js --dry    # report only, write nothing
 *
 * Reads MONGO_URI from the root .env, exactly like the server does.
 */
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');

require('dotenv').config({ path: path.join(__dirname, '../../.env') });

const imageStore = require('../services/imageStore');

const UPLOADS_DIR = path.join(__dirname, '../uploads');
const DRY_RUN = process.argv.includes('--dry');

const MIME_BY_EXTENSION = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.heic': 'image/heic',
  '.heif': 'image/heif',
};

async function main() {
  if (!process.env.MONGO_URI) {
    console.error('MONGO_URI is not set. Add it to the root .env and retry.');
    process.exit(1);
  }
  if (!fs.existsSync(UPLOADS_DIR)) {
    console.log(`Nothing to migrate: ${UPLOADS_DIR} does not exist.`);
    process.exit(0);
  }

  await mongoose.connect(process.env.MONGO_URI, { dbName: 'civic_connect' });
  console.log(`Connected to MongoDB. Dry run: ${DRY_RUN}\n`);

  const gridfsBucket = new mongoose.mongo.GridFSBucket(mongoose.connection.db, {
    bucketName: imageStore.BUCKET_NAME,
  });

  const files = fs
    .readdirSync(UPLOADS_DIR)
    .filter((name) => fs.statSync(path.join(UPLOADS_DIR, name)).isFile());

  // One existence check per distinct filename, up front.
  const existing = new Set();
  for await (const file of gridfsBucket.find({}, { projection: { filename: 1 } })) {
    existing.add(file.filename);
  }

  let migrated = 0;
  let skipped = 0;
  let failed = 0;
  let bytesBefore = 0;
  let bytesAfter = 0;

  for (const name of files) {
    if (existing.has(name)) {
      skipped += 1;
      continue;
    }

    const sourcePath = path.join(UPLOADS_DIR, name);
    const buffer = fs.readFileSync(sourcePath);
    bytesBefore += buffer.length;

    if (DRY_RUN) {
      console.log(`[dry] ${name} (${(buffer.length / 1024).toFixed(0)} KB)`);
      migrated += 1;
      continue;
    }

    try {
      const stored = await imageStore.saveImage({
        buffer,
        originalname: name,
        mimetype: MIME_BY_EXTENSION[path.extname(name).toLowerCase()] || 'application/octet-stream',
        filename: name, // keep the URL every stored issue already points at
      });
      bytesAfter += stored.bytes;
      migrated += 1;
      console.log(
        `  ✔ ${name} → GridFS  ${(buffer.length / 1024).toFixed(0)} KB → ` +
          `${(stored.bytes / 1024).toFixed(0)} KB` +
          (stored.compressed ? '' : '  (stored as-is; encoder could not read it)')
      );
    } catch (error) {
      failed += 1;
      console.error(`  ✖ ${name}: ${error.message}`);
    }
  }

  console.log(
    `\nDone. migrated=${migrated} skipped(already in GridFS)=${skipped} failed=${failed}` +
      (bytesBefore > 0
        ? `\nDisk total: ${(bytesBefore / 1024 / 1024).toFixed(1)} MB` +
          (DRY_RUN ? '' : ` → GridFS total: ${(bytesAfter / 1024 / 1024).toFixed(1)} MB`)
        : '')
  );

  await mongoose.disconnect();
}

main().catch(async (error) => {
  console.error('Migration failed:', error);
  if (mongoose.connection.readyState === 1) await mongoose.disconnect();
  process.exit(1);
});
