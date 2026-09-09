const Issue = require('../models/Issue');

/**
 * Silence is assent.
 *
 * A complaint left in `pending` verification forever is worse than one nobody
 * checked: it never closes, so it pollutes resolution metrics and sits in the
 * queue behind work that matters. After the response window the state settles
 * to `auto_confirmed`, which is distinct from `confirmed` so a report can still
 * tell the difference between a citizen who agreed and a citizen who never
 * answered.
 *
 * Implemented as an idempotent bulk update rather than a scheduled job. It is a
 * single indexed write, so the read paths that care about correctness — the
 * officer queue and the ward statistics — can call it inline without a
 * scheduler, and the project keeps no background process to deploy or babysit.
 */
async function settleExpired(now = new Date()) {
  const result = await Issue.updateMany(
    {
      'verification.state': 'pending',
      'verification.dueBy': { $lt: now },
    },
    { $set: { 'verification.state': 'auto_confirmed' } }
  );
  return result.modifiedCount || 0;
}

/** How long a reporter has to dispute a claimed fix. */
const VERIFICATION_WINDOW_HOURS = 72;

function verificationDeadline(from = new Date()) {
  return new Date(from.getTime() + VERIFICATION_WINDOW_HOURS * 3600 * 1000);
}

module.exports = { settleExpired, verificationDeadline, VERIFICATION_WINDOW_HOURS };
