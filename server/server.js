const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

// Validates configuration and exits if anything required is missing, so a
// misconfigured server never reaches the point of serving requests.
const config = require('./config/env');
const connectDB = require('./config/db');

const app = express();

connectDB();

/**
 * Origin policy.
 *
 * Native clients ignore CORS entirely, so this only governs web builds. With
 * CORS_ORIGINS unset every origin is allowed, which is right for local
 * development and wrong everywhere else — `config` warns about it at boot.
 */
app.use(
  cors({
    origin: config.corsOrigins.length > 0 ? config.corsOrigins : true,
    credentials: true,
  })
);

// Bounded so a malformed or hostile request cannot exhaust memory. Photographs
// arrive as multipart, not JSON, so this does not need to be large.
app.use(express.json({ limit: '256kb' }));

/**
 * Blanket ceiling. Generous enough that ordinary use never notices, low enough
 * that a runaway client or scraper is stopped.
 */
app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 600,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    message: { message: 'Too many requests. Wait a few minutes and try again.' },
  })
);

/**
 * Credential endpoints get their own much tighter budget.
 *
 * Without this, nothing stopped an attacker working through a password list
 * against /login as fast as the network allowed.
 */
app.use(
  ['/api/auth/login', '/api/auth/signup', '/api/auth/google'],
  rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 20,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    skipSuccessfulRequests: true,
    message: {
      message: 'Too many sign-in attempts. Wait 15 minutes and try again.',
    },
  })
);

// Uploaded photographs. Immutable once written, so they cache indefinitely.
app.use(
  '/uploads',
  express.static(path.join(__dirname, 'uploads'), {
    maxAge: '30d',
    immutable: true,
    // These are user-supplied files; never let the browser guess a type for
    // them or run one as a document.
    setHeaders: (res) => {
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('Content-Disposition', 'inline');
    },
  })
);

app.use('/api/auth', require('./routes/auth'));
app.use('/api/issues', require('./routes/issues'));
app.use('/api/comments', require('./routes/comments'));

app.get('/', (req, res) => {
  res.json({ service: 'Civic Connect API', status: 'running' });
});

/**
 * Health check for whatever ends up running this.
 */
app.get('/health', (req, res) => {
  const mongoose = require('mongoose');
  const connected = mongoose.connection.readyState === 1;
  res.status(connected ? 200 : 503).json({
    status: connected ? 'ok' : 'degraded',
    database: connected ? 'connected' : 'disconnected',
  });
});

// Unknown route. JSON, because every client here parses JSON and an HTML error
// page produces a confusing parse failure rather than a useful message.
app.use((req, res) => {
  res.status(404).json({ message: `No route for ${req.method} ${req.originalUrl}` });
});

/**
 * Last-resort handler.
 *
 * Multer rejects oversized or wrong-typed uploads by throwing, and those need
 * to reach the client as something it can display rather than a stack trace.
 */
app.use((err, req, res, next) => {
  if (res.headersSent) return next(err);

  if (err && err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ message: 'That photograph is too large (limit 8 MB).' });
  }
  if (err && err.code === 'INVALID_FILE_TYPE') {
    return res.status(415).json({ message: err.message });
  }
  if (err && err.code === 'LIMIT_FILE_COUNT') {
    return res.status(413).json({ message: 'Too many photographs in one complaint.' });
  }
  if (err && err.status === 400 && 'body' in err) {
    return res.status(400).json({ message: 'Request body was not valid JSON.' });
  }

  console.error('Unhandled error:', err);
  res.status(500).json({ message: 'Something went wrong on the server.' });
});

app.listen(config.port, () => {
  console.log(`\nCivic Connect API listening on port ${config.port}\n`);
  config.reportWarnings();
});
