/**
 * Serves stored photographs.
 *
 * Photographs live in MongoDB GridFS and are streamed out on request. Files
 * that predate the migration — including the seed images — are still read
 * from the legacy uploads directory, so nothing already referenced by a
 * stored complaint breaks. Either way the bytes are immutable once written,
 * so they cache indefinitely, and are never allowed to be sniffed into
 * another type or treated as a document.
 */
const express = require('express');
const path = require('path');
const imageStore = require('../services/imageStore');

const router = express.Router();

// Kept only for the legacy fallback; new photographs never touch the disk.
const LEGACY_UPLOADS_DIR = path.join(__dirname, '../uploads');

router.get('/:filename', async (req, res) => {
  // `basename` keeps a crafted parameter such as `..%2fserver.js` from leaving
  // the uploads directory on the legacy path.
  const filename = path.basename(req.params.filename);
  if (filename !== req.params.filename) {
    return res.status(404).json({ message: 'File not found' });
  }

  try {
    const stored = await imageStore.getImage(filename);
    if (stored) {
      res.setHeader('Content-Type', stored.file.contentType || 'application/octet-stream');
      res.setHeader('Content-Length', stored.file.length);
      res.setHeader('Cache-Control', 'public, max-age=2592000, immutable');
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('Content-Disposition', 'inline');
      stored.stream.on('error', (streamErr) => {
        console.error('GridFS stream error:', streamErr.message);
        res.end();
      });
      stored.stream.pipe(res);
      return;
    }

    // Not in MongoDB — fall back to the legacy directory.
    res.sendFile(
      path.join(LEGACY_UPLOADS_DIR, filename),
      {
        maxAge: '30d',
        immutable: true,
        setHeaders: (sendFileRes) => {
          sendFileRes.setHeader('X-Content-Type-Options', 'nosniff');
          sendFileRes.setHeader('Content-Disposition', 'inline');
        },
      },
      (err) => {
        if (err && !res.headersSent) {
          res.status(404).json({ message: 'File not found' });
        }
      }
    );
  } catch (error) {
    console.error('Uploads route error:', error.message);
    if (!res.headersSent) {
      res.status(500).json({ message: 'Failed to read file' });
    }
  }
});

module.exports = router;
