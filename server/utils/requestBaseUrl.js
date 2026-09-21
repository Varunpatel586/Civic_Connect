/**
 * The address a response is being delivered from.
 *
 * Photograph URLs are stored absolute and rebuilt at read time, so the server
 * has to know its own public address. `API_URL` is a fine answer for a laptop
 * and a poor one for a deployment: Render hands out hostnames with a suffix
 * nobody can predict — `civic-connect-api-eq0j.onrender.com` — and appends a
 * new one whenever a name is taken or a service is renamed. A hand-typed
 * `API_URL` that disagrees with reality produces image links to a host that
 * does not exist, which is exactly how the deployed app came to advertise
 * `https://civic-connect-api.onrender.com/…` while living at
 * `https://civic-connect-api-eq0j.onrender.com`.
 *
 * The request itself is the authoritative answer: whatever host the client
 * reached is, by definition, a host the client can reach again. It is therefore
 * held in async context for the life of the request, which keeps
 * `absoluteStoredUrl` a one-argument function and means no response path can
 * forget to pass an origin through — the failure mode of threading it by hand
 * through every serializer, which is how this went wrong in the first place.
 *
 * Outside a request — a background job, a script — the store is empty and
 * callers fall back to `RENDER_EXTERNAL_URL`, which Render injects, and then to
 * `API_URL`.
 */
const { AsyncLocalStorage } = require('async_hooks');

const storage = new AsyncLocalStorage();

/** `https://host[:port]` for this request, or null when there is no Host. */
function requestBaseUrl(req) {
  const host = req.headers['x-forwarded-host'] || req.get('host');
  if (!host) return null;

  // Render terminates TLS a hop in front of the app, so the socket speaks plain
  // http even though the client's request was https. Rebuilding an https URL as
  // http makes Android refuse it as cleartext.
  const forwarded = req.headers['x-forwarded-proto'];
  const proto = forwarded ? forwarded.split(',')[0].trim() : req.protocol;

  return `${proto}://${host}`;
}

/** Express middleware: publishes the request's own origin to the response. */
function withRequestBaseUrl(req, res, next) {
  const base = requestBaseUrl(req);
  if (!base) return next();
  storage.run(base, next);
}

/** The origin of the request being answered, if it is running on one. */
function currentRequestBaseUrl() {
  return storage.getStore() || null;
}

module.exports = { requestBaseUrl, withRequestBaseUrl, currentRequestBaseUrl };
