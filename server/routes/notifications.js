const express = require('express');
const auth = require('../middleware/auth');
const Notification = require('../models/Notification');
const User = require('../models/User');

const router = express.Router();

/** Wire shape for one inbox row. Snake_case, matching every other payload. */
const serializeNotification = (n) => ({
  id: n._id.toString(),
  issue_id: n.issueId ? n.issueId.toString() : null,
  type: n.type,
  title: n.title,
  body: n.body || '',
  reference: n.reference || '',
  read: Boolean(n.readAt),
  read_at: n.readAt || null,
  created_at: n.createdAt,
});

// @route   GET api/notifications
// @desc    This user's inbox, newest first
// @access  Private
router.get('/', auth, async (req, res) => {
  const { limit = 50, unread_only } = req.query;
  const capped = Math.min(Math.max(Number.parseInt(limit, 10) || 50, 1), 200);

  try {
    const query = { userId: req.user.id };
    if (unread_only === 'true') query.readAt = null;

    const rows = await Notification.find(query)
      .sort({ createdAt: -1 })
      .limit(capped)
      .lean();

    res.json(rows.map(serializeNotification));
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET api/notifications/unread-count
// @desc    Badge count for the home screen
// @access  Private
router.get('/unread-count', auth, async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      userId: req.user.id,
      readAt: null,
    });
    res.json({ count });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   PATCH api/notifications/:id/read
// @desc    Mark one message read
// @access  Private
router.patch('/:id/read', auth, async (req, res) => {
  try {
    // Scoped by userId as well as id so one user cannot mark another's mail.
    const updated = await Notification.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },
      { $set: { readAt: new Date() } },
      { new: true }
    );

    if (!updated) return res.status(404).json({ message: 'Notification not found' });
    res.json(serializeNotification(updated));
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST api/notifications/read-all
// @desc    Clear the badge
// @access  Private
router.post('/read-all', auth, async (req, res) => {
  try {
    const result = await Notification.updateMany(
      { userId: req.user.id, readAt: null },
      { $set: { readAt: new Date() } }
    );
    res.json({ updated: result.modifiedCount || 0 });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST api/notifications/device-token
// @desc    Register this device for push
// @access  Private
router.post('/device-token', auth, async (req, res) => {
  const token = (req.body.token || '').trim();
  if (!token) return res.status(400).json({ message: 'token is required' });

  try {
    // addToSet, so re-registering on every app launch stays idempotent.
    await User.updateOne(
      { _id: req.user.id },
      { $addToSet: { deviceTokens: token } }
    );
    res.json({ registered: true });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   DELETE api/notifications/device-token
// @desc    Unregister on logout, so the next account on this handset does not
//          inherit the previous one's pushes
// @access  Private
router.delete('/device-token', auth, async (req, res) => {
  // Query string, not body: the Flutter client's delete() sends none.
  const token = ((req.query.token || req.body.token) || '').trim();
  if (!token) return res.status(400).json({ message: 'token is required' });

  try {
    await User.updateOne(
      { _id: req.user.id },
      { $pull: { deviceTokens: token } }
    );
    res.json({ registered: false });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
