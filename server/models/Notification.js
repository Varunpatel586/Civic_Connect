const mongoose = require('mongoose');

/**
 * A delivered message in a citizen's or officer's inbox.
 *
 * This collection — not FCM — is the source of truth. Push is a best-effort
 * nudge: it is dropped when the device is offline, the token has rotated, or
 * the app was reinstalled. A notification that only ever existed as a push is
 * a notification the user can silently never receive, which is exactly the
 * failure the closed loop cannot tolerate. So every message is written here
 * first and pushed second.
 */
const NotificationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  issueId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Issue',
    default: null,
  },
  type: {
    type: String,
    enum: [
      'status_changed',
      'verification_requested',
      'verification_confirmed',
      'verification_disputed',
      'escalated',
    ],
    required: true,
  },
  title: { type: String, required: true },
  body: { type: String, default: '' },
  // Complaint reference (CC-2026-MH-93047) carried so the inbox can render a
  // row without a join back to the issue.
  reference: { type: String, default: '' },
  readAt: { type: Date, default: null },
}, { timestamps: true });

// The inbox query: this user's messages, newest first.
NotificationSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', NotificationSchema);
