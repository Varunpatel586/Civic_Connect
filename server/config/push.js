/**
 * Firebase Cloud Messaging adapter.
 *
 * Deliberately optional. The project runs, demos, and passes its tests with no
 * Firebase credentials at all — `send` becomes a no-op and the inbox still
 * receives every message. Push turns itself on the moment a service account is
 * configured, so nobody needs a Firebase project to work on the rest of the app.
 *
 * To enable: set FIREBASE_SERVICE_ACCOUNT to the path of a service-account JSON
 * key and run `npm install firebase-admin` in server/.
 */
const path = require('path');

let messaging = null;
let state = 'uninitialised';

function init() {
  if (state !== 'uninitialised') return;

  const keyPath = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!keyPath) {
    state = 'disabled:no-credentials';
    return;
  }

  try {
    // Required lazily so the dependency stays optional.
    const admin = require('firebase-admin');
    const resolved = path.isAbsolute(keyPath)
      ? keyPath
      : path.join(__dirname, '..', keyPath);

    if (admin.apps.length === 0) {
      admin.initializeApp({ credential: admin.credential.cert(require(resolved)) });
    }
    messaging = admin.messaging();
    state = 'enabled';
  } catch (err) {
    // A missing package or an unreadable key must not take the API down; the
    // inbox is what actually guarantees delivery.
    state = `disabled:${err.code || err.message}`;
  }
}

/** True when pushes will actually leave the process. */
function isEnabled() {
  init();
  return state === 'enabled';
}

function status() {
  init();
  return state;
}

/**
 * Best-effort fan-out to a set of device tokens.
 *
 * Returns the tokens the FCM service rejected as permanently invalid, so the
 * caller can prune them. Never throws.
 */
async function send(tokens, { title, body, data = {} }) {
  init();
  if (state !== 'enabled' || tokens.length === 0) return { sent: 0, invalid: [] };

  try {
    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      // FCM requires every data value to be a string.
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
    });

    const invalid = [];
    response.responses.forEach((result, i) => {
      const code = result.error && result.error.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        invalid.push(tokens[i]);
      }
    });

    return { sent: response.successCount, invalid };
  } catch (err) {
    console.error('[push] send failed:', err.message);
    return { sent: 0, invalid: [] };
  }
}

module.exports = { send, isEnabled, status };
