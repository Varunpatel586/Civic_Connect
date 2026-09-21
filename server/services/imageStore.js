/**
 * Photograph storage in MongoDB (GridFS), with compression on the way in.
 *
 * Photographs used to be written to `server/uploads` on disk, which meant they
 * vanished on every redeploy unless a persistent disk was attached, and grew
 * without bound. Storing them in GridFS alongside the complaints they prove
 * removes the disk from the deployment entirely.
 *
 * Two constraints shaped this module:
 *
 * 1. Atlas M0 caps the whole database at 512 MB. A phone camera produces
 *    3-6 MB photographs, so storing them raw would fill the free tier in
 *    under a hundred uploads and lock the database read-only. Every image is
 *    therefore resized and re-encoded to JPEG before it is written — a 5 MB
 *    photograph lands at a few hundred kilobytes, which puts thousands of
 *    photographs inside the cap.
 *
 * 2. The wire contract must not move. Whatever a client uploads, the served
 *    URL stays `<API_URL>/uploads/<filename>`, and the bytes served are
 *    re-encoded JPEG. Both the Flutter client and the FastAPI vision service
 *    fetch photographs by URL and neither needs to know where they are kept.
 */
const path = require('path');
const mongoose = require('mongoose');
const sharp = require('sharp');

const BUCKET_NAME = 'uploads';

/** Longest edge for incoming photographs. Wide enough that ORB feature
 * matching and CLIP classification stay reliable on the stored evidence. */
const COMPRESSED_WIDTH = 1200;
const COMPRESSED_HEIGHT = 1200;
const JPEG_QUALITY = 70;

let bucketPromise = null;

/**
 * The GridFS bucket, created once the mongoose connection is live.
 *
 * Created lazily on first use rather than at require time, because the server
 * registers its routes before `connectDB()` resolves.
 */
function bucket() {
  if (!bucketPromise) {
    bucketPromise = new Promise((resolve, reject) => {
      const connection = mongoose.connection;
      const create = () => {
        try {
          resolve(
            new mongoose.mongo.GridFSBucket(connection.db, {
              bucketName: BUCKET_NAME,
            })
          );
        } catch (error) {
          reject(error);
        }
      };
      if (connection.readyState === 1) {
        create();
      } else {
        connection.once('connected', create);
      }
    });
  }
  return bucketPromise;
}

/**
 * Stores one photograph and returns the filename it will be served under.
 *
 * The buffer is re-encoded to JPEG at {@link COMPRESSED_WIDTH}. Formats the
 * encoder cannot read (notably HEIC, which libvips only supports when libheif
 * is compiled in) are stored as-is rather than failing the upload — a larger
 * but present photograph beats a rejected report.
 *
 * `filename` is optional. Migration passes it so an existing record's URL
 * keeps resolving after its bytes move from disk into MongoDB; live uploads
 * omit it and get a fresh collision-proof name.
 *
 * @param {{buffer: Buffer, originalname?: string, mimetype?: string, filename?: string}} upload
 * @returns {Promise<{filename: string, compressed: boolean, bytes: number}>}
 */
async function saveImage({ buffer, originalname, mimetype, filename: requestedName }) {
  let output = buffer;
  let outputMimetype = mimetype || 'application/octet-stream';
  let compressed = false;

  try {
    output = await sharp(buffer)
      .rotate() // honour EXIF orientation, which stripping metadata would lose
      .resize({
        width: COMPRESSED_WIDTH,
        height: COMPRESSED_HEIGHT,
        fit: 'inside', // bounds the longest edge for portrait and landscape alike
        withoutEnlargement: true,
      })
      .jpeg({ quality: JPEG_QUALITY, mozjpeg: true })
      .toBuffer();
    outputMimetype = 'image/jpeg';
    compressed = true;
  } catch (error) {
    console.warn(
      `[imageStore] Could not re-encode ${originalname || 'upload'}; storing original bytes: ${error.message}`
    );
  }

  // Same filename scheme the disk storage used, so nothing downstream —
  // URL caches, seeded records, the vision service — can tell the difference.
  let filename = requestedName;
  if (!filename) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const extension = compressed ? '.jpg' : path.extname(originalname || '') || '.bin';
    filename = `photo-${uniqueSuffix}${extension}`;
  }

  const gridfsBucket = await bucket();
  await new Promise((resolve, reject) => {
    const uploadStream = gridfsBucket.openUploadStream(filename, {
      contentType: outputMimetype,
      metadata: {
        originalName: originalname || filename,
        originalMimetype: mimetype || null,
        originalSize: buffer.length,
      },
    });
    uploadStream.on('error', reject);
    uploadStream.on('finish', resolve);
    uploadStream.end(output);
  });

  return { filename, compressed, bytes: output.length };
}

/**
 * Locates one stored photograph and a stream of its bytes.
 *
 * @param {string} filename
 * @returns {Promise<{file: object, stream: import('stream').Readable} | null>}
 */
async function getImage(filename) {
  const gridfsBucket = await bucket();
  const file = await gridfsBucket.find({ filename }).limit(1).next();
  if (!file) return null;
  return { file, stream: gridfsBucket.openDownloadStream(file._id) };
}

module.exports = { saveImage, getImage, BUCKET_NAME };