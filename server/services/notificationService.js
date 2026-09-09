const Notification = require('../models/Notification');
const User = require('../models/User');
const push = require('../config/push');
const { referenceFor } = require('../config/reference');

/**
 * The one place a notification is created.
 *
 * Every caller goes through `fanOut`, so the ordering guarantee — persist to
 * the inbox first, push second — holds everywhere and cannot be forgotten at a
 * call site. A push failure is logged and swallowed: the message is already
 * durable by the time it is attempted.
 */

/** Drops falsy and duplicate ids, and anyone the caller asked to skip. */
function recipientSet(ids, { exclude = [] } = {}) {
  const skip = new Set(exclude.filter(Boolean).map(String));
  const seen = new Set();
  const out = [];
  for (const id of ids || []) {
    if (!id) continue;
    const key = String(id);
    if (skip.has(key) || seen.has(key)) continue;
    seen.add(key);
    out.push(id);
  }
  return out;
}

/**
 * Writes one notification per recipient, then attempts a single multicast push.
 *
 * `exclude` keeps a user from being told about their own action — the officer
 * who set the status does not need a message saying the status was set.
 */
async function fanOut({ recipients, issue, type, title, body = '', exclude = [] }) {
  const targets = recipientSet(recipients, { exclude });
  if (targets.length === 0) return { notified: 0, pushed: 0 };

  const reference = issue ? referenceFor(issue) : '';

  // Durable first. If the process dies after this line, the user still sees it.
  await Notification.insertMany(
    targets.map((userId) => ({
      userId,
      issueId: issue ? issue._id : null,
      type,
      title,
      body,
      reference,
    }))
  );

  const users = await User.find(
    { _id: { $in: targets } },
    { deviceTokens: 1 }
  ).lean();

  const tokens = [...new Set(users.flatMap((u) => u.deviceTokens || []))];
  if (tokens.length === 0) return { notified: targets.length, pushed: 0 };

  const { sent, invalid } = await push.send(tokens, {
    title,
    body,
    data: {
      type,
      issue_id: issue ? issue._id.toString() : '',
      reference,
    },
  });

  // Tokens FCM reports as permanently dead are pulled, so the list does not
  // grow forever with tokens from uninstalled apps.
  if (invalid.length > 0) {
    await User.updateMany(
      { deviceTokens: { $in: invalid } },
      { $pull: { deviceTokens: { $in: invalid } } }
    );
  }

  return { notified: targets.length, pushed: sent };
}

module.exports = { fanOut };
