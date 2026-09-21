/**
 * Rewrites stored photograph URLs to the host this deployment is serving from.
 *
 * Photograph URLs are written into documents as absolute URLs at upload time,
 * built from whatever `API_URL` the uploading server had. A complaint filed
 * against a laptop therefore stores `http://localhost:5000/uploads/…` — which
 * a phone cannot load, and which breaks again the moment the deployment moves.
 * The bytes live on this server either way, so the fix belongs at read time:
 * any URL pointing into `/uploads/` is rebuilt against the current `API_URL`
 * and the stored document is left untouched.
 *
 * URLs that do not point into `/uploads/` are other people's (Google avatars,
 * stock photographs) and pass through unchanged.
 */
const config = require('../config/env');

function absoluteStoredUrl(value) {
  if (!value || typeof value !== 'string') return value;

  const marker = '/uploads/';
  const markerIndex = value.indexOf(marker);
  if (markerIndex === -1) return value;

  let filename = value.slice(markerIndex + marker.length);
  const queryIndex = filename.indexOf('?');
  if (queryIndex !== -1) filename = filename.slice(0, queryIndex);
  if (!filename) return value;

  return `${config.apiUrl}/uploads/${filename}`;
}

module.exports = absoluteStoredUrl;
