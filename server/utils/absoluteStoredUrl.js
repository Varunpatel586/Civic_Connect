/**
 * Rewrites stored photograph URLs to the host this deployment is serving from.
 *
 * Photograph URLs are written into documents as absolute URLs at upload time,
 * built from whatever `API_URL` the uploading server had. A complaint filed
 * against a laptop therefore stores `http://localhost:5000/uploads/…` — which
 * a phone cannot load, and which breaks again the moment the deployment moves.
 * The bytes live on this server either way, so the fix belongs at read time:
 * any URL pointing into `/uploads/` is rebuilt against the host the current
 * request arrived on, and the stored document is left untouched. Using the
 * request's own origin rather than a configured one matters because a
 * deployment's public hostname is not always what configuration claims — see
 * utils/requestBaseUrl.js.
 *
 * URLs that do not point into `/uploads/` are other people's (Google avatars,
 * stock photographs) and pass through unchanged.
 */
const config = require('../config/env');
const { currentRequestBaseUrl } = require('./requestBaseUrl');

/** First origin that knows where this deployment actually lives. */
const fallbackBaseUrl = () =>
  currentRequestBaseUrl() || config.renderExternalUrl || config.apiUrl;

function absoluteStoredUrl(value, baseUrl) {
  if (!value || typeof value !== 'string') return value;

  const marker = '/uploads/';
  const markerIndex = value.indexOf(marker);
  if (markerIndex === -1) return value;

  let filename = value.slice(markerIndex + marker.length);
  const queryIndex = filename.indexOf('?');
  if (queryIndex !== -1) filename = filename.slice(0, queryIndex);
  if (!filename) return value;

  // This doubles as an Array.map callback, and map passes the element index as
  // the second argument — so only a real string counts as an override. A
  // trailing slash would produce `…//uploads/…` and a 404.
  const base = (typeof baseUrl === 'string' && baseUrl ? baseUrl : fallbackBaseUrl())
    .replace(/\/+$/, '');

  return `${base}/uploads/${filename}`;
}

module.exports = absoluteStoredUrl;
