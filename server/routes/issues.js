const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const auth = require('../middleware/auth');
const admin = require('../middleware/admin');
const Issue = require('../models/Issue');
const Vote = require('../models/Vote');
const Upvote = require('../models/Upvote');
const jwt = require('jsonwebtoken');
const sla = require('../config/sla');
const config = require('../config/env');
const { wardFilter, officerCoversWard } = require('../config/wards');

const getUserIdFromRequest = (req) => {
  const authHeader = req.header('Authorization');
  if (!authHeader) return null;
  const token = authHeader.replace('Bearer ', '');
  if (!token) return null;
  try {
    const decoded = jwt.verify(token, config.jwtSecret);
    return decoded.user.id;
  } catch (err) {
    return null;
  }
};

// Ensure uploads folder exists
const uploadDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Multer Config
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    // Safe because fileFilter already rejected anything outside the allowlist.
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, 'photo-' + uniqueSuffix + ext);
  },
});
/**
 * Only real photographs, and only small ones.
 *
 * Both the declared type and the extension must be on the allowlist: the
 * extension is what ends up on disk and in the served URL, and an unchecked one
 * let any authenticated account drop arbitrary files into a publicly served
 * directory.
 */
const ALLOWED_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
]);
const ALLOWED_EXTENSIONS = new Set([
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.heic',
  '.heif',
]);
const MAX_PHOTO_BYTES = 8 * 1024 * 1024;

const upload = multer({
  storage,
  limits: { fileSize: MAX_PHOTO_BYTES, files: 1 },
  fileFilter: (req, file, cb) => {
    const extension = path.extname(file.originalname || '').toLowerCase();
    if (!ALLOWED_MIME_TYPES.has(file.mimetype) || !ALLOWED_EXTENSIONS.has(extension)) {
      const error = new Error('Only JPEG, PNG, WebP or HEIC photographs are accepted.');
      error.code = 'INVALID_FILE_TYPE';
      return cb(error);
    }
    cb(null, true);
  },
});

/**
 * The single wire format for an issue.
 *
 * Field names stay snake_case because the Dart models were written against the
 * previous backend and still parse that shape. Every caller goes through here
 * so a new field cannot land on one endpoint and go missing on another.
 */
const serializeIssue = (issue, { userVote = null, includeHistory = false } = {}) => {
  // Populated only when the query asked for it; an unpopulated userId is an
  // ObjectId, which is also typeof 'object', so test for a real field instead.
  const populated =
    issue.userId && typeof issue.userId === 'object' && 'username' in issue.userId;
  const user = populated ? issue.userId : null;

  const payload = {
    id: issue._id.toString(),
    user_id: user ? user._id.toString() : issue.userId ? issue.userId.toString() : '',
    title: issue.title,
    category: issue.category,
    description: issue.description,
    image_url: issue.imageUrl,
    image_urls: issue.imageUrls,
    latitude: issue.latitude,
    longitude: issue.longitude,
    address: issue.address,
    ward: issue.ward || null,
    status: issue.status,
    agree_count: issue.agreeCount,
    disagree_count: issue.disagreeCount,
    user_vote: userVote,
    due_at: sla.dueDate(issue),
    is_overdue: sla.isOverdue(issue),
    closed_at: issue.closedAt || null,
    timestamp: issue.createdAt,
    created_at: issue.createdAt,
    user: {
      username: user ? user.username : 'Unknown',
      avatar_url: user ? user.avatarUrl : null,
    },
  };

  if (includeHistory) {
    payload.status_history = (issue.statusHistory || []).map((entry) => ({
      status: entry.status,
      changed_at: entry.changedAt,
      note: entry.note || '',
    }));
  }

  return payload;
};

/** Looks up the requester's votes across a batch of issues in one query. */
const voteMapFor = async (userId, issues) => {
  if (!userId || issues.length === 0) return {};
  const votes = await Vote.find({
    issueId: { $in: issues.map((i) => i._id) },
    userId,
  });
  return votes.reduce((map, vote) => {
    map[vote.issueId.toString()] = vote.isAgree ? 'agree' : 'disagree';
    return map;
  }, {});
};

// @route   POST api/issues/upload
// @desc    Upload file to server storage
// @access  Private
router.post('/upload', auth, upload.single('photo'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    const hostUrl = config.apiUrl;
    const fileUrl = `${hostUrl}/uploads/${req.file.filename}`;

    res.json({ url: fileUrl });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server upload error' });
  }
});

// @route   POST api/issues
// @desc    Create new issue
// @access  Private
router.post('/', auth, async (req, res) => {
  const { title, description, category, imageUrl, imageUrls, latitude, longitude, address } = req.body;

  try {
    // Validate before writing. Previously a missing category threw inside
    // `category.replace(...)` and surfaced as an opaque 500, and absent
    // coordinates were coerced to 0, 0 — a complaint in the Gulf of Guinea.
    const allowedCategories = Issue.schema.path('category').enumValues;
    if (!category || !allowedCategories.includes(category)) {
      return res.status(400).json({
        message: `Category must be one of: ${allowedCategories.join(', ')}`,
      });
    }

    if (!imageUrl || typeof imageUrl !== 'string') {
      return res.status(400).json({ message: 'A complaint needs at least one photograph' });
    }

    const lat = Number.parseFloat(latitude);
    const lng = Number.parseFloat(longitude);

    if (!Number.isFinite(lat) || lat < -90 || lat > 90) {
      return res.status(400).json({ message: 'Latitude must be between -90 and 90' });
    }
    if (!Number.isFinite(lng) || lng < -180 || lng > 180) {
      return res.status(400).json({ message: 'Longitude must be between -180 and 180' });
    }
    if (lat === 0 && lng === 0) {
      return res.status(400).json({
        message: 'A complaint needs a real location before it can be filed',
      });
    }

    const trimmedDescription = (description || '').toString().trim();
    if (trimmedDescription.length > 2000) {
      return res.status(400).json({ message: 'Description is too long (2000 characters maximum)' });
    }

    const resolvedTitle = (title || category.replace('_', ' ').toUpperCase())
      .toString()
      .trim()
      .slice(0, 140);

    const newIssue = new Issue({
      userId: req.user.id,
      title: resolvedTitle,
      description: trimmedDescription,
      category,
      imageUrl,
      imageUrls: Array.isArray(imageUrls) && imageUrls.length > 0 ? imageUrls : [imageUrl],
      latitude: lat,
      longitude: lng,
      address,
      // Open the record with its filing entry so the timeline is never empty.
      statusHistory: [
        {
          status: 'Pending',
          changedBy: req.user.id,
          changedAt: new Date(),
          note: 'Complaint filed',
        },
      ],
    });

    const issue = await newIssue.save();
    res.status(201).json(issue);
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET api/issues/nearby
// @desc    Fetch issues near a location
// @access  Public
router.get('/nearby', async (req, res) => {
  const { lat, lng, radius_km = 5.0, limit = 50 } = req.query;

  if (lat === undefined || lng === undefined) {
    return res.status(400).json({ message: 'Latitude and longitude are required' });
  }

  const targetLat = Number.parseFloat(lat);
  const targetLng = Number.parseFloat(lng);
  const radius = Number.parseFloat(radius_km);
  const maxLimit = Math.min(Math.max(Number.parseInt(limit, 10) || 50, 1), 200);

  if (!Number.isFinite(targetLat) || !Number.isFinite(targetLng)) {
    return res.status(400).json({ message: 'Latitude and longitude must be numbers' });
  }
  if (!Number.isFinite(radius) || radius <= 0) {
    return res.status(400).json({ message: 'radius_km must be a positive number' });
  }

  try {
    // $geoWithin/$centerSphere uses the 2dsphere index, so Mongo does the
    // filtering, the sort and the limit. This route used to load every
    // complaint in the database and measure distances in JavaScript.
    //
    // $centerSphere takes its radius in radians: kilometres over the Earth's
    // mean radius.
    const EARTH_RADIUS_KM = 6378.1;

    const issues = await Issue.find({
      location: {
        $geoWithin: {
          $centerSphere: [[targetLng, targetLat], radius / EARTH_RADIUS_KM],
        },
      },
    })
      .sort({ createdAt: -1 })
      .limit(maxLimit)
      .populate('userId', 'username avatarUrl')
      .lean();

    const userVotes = await voteMapFor(getUserIdFromRequest(req), issues);

    res.json(
      issues.map((issue) =>
        serializeIssue(issue, { userVote: userVotes[issue._id.toString()] || null })
      )
    );
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET api/issues/user
// @desc    Get current user's issues
// @access  Private
router.get('/user', auth, async (req, res) => {
  try {
    const issues = await Issue.find({ userId: req.user.id })
      .populate('userId', 'username avatarUrl')
      .sort({ createdAt: -1 })
      .lean();

    const userVotes = await voteMapFor(req.user.id, issues);

    res.json(
      issues.map((issue) =>
        serializeIssue(issue, { userVote: userVotes[issue._id.toString()] || null })
      )
    );
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET api/issues/stats
// @desc    Ward-level counters for the municipal overview
// @access  Admin
router.get('/stats', auth, admin, async (req, res) => {
  try {
    // Read-and-reduce rather than an aggregation pipeline: the overdue test is
    // per-category window arithmetic that Mongo cannot express cheaply, and at
    // municipal-ward volumes this stays well inside a single round trip.
    // Scoped: an officer's numbers should describe the ward they answer
    // for, not the whole city.
    const issues = await Issue.find(wardFilter(req.user.wards)).lean();
    const now = new Date();

    const open = issues.filter((issue) => !sla.isClosed(issue));
    const overdue = open.filter((issue) => sla.isOverdue(issue, now));
    const resolved = issues.filter((issue) => issue.status === 'Resolved');

    // Only complaints with a recorded closure contribute — an unmeasured one
    // would otherwise drag the average toward zero.
    const measured = resolved.filter((issue) => issue.closedAt);
    const avgCloseDays = measured.length
      ? measured.reduce(
          (total, issue) =>
            total + (new Date(issue.closedAt) - new Date(issue.createdAt)),
          0
        ) /
        measured.length /
        86400000
      : null;

    const counts = issues.reduce((map, issue) => {
      map[issue.category] = (map[issue.category] || 0) + 1;
      return map;
    }, {});

    const byCategory = Object.entries(counts)
      .map(([category, count]) => ({ category, count }))
      .sort((a, b) => b.count - a.count);

    res.json({
      wards: req.user.wards.length > 0 ? req.user.wards : null,
      total: issues.length,
      open: open.length,
      overdue: overdue.length,
      resolved: resolved.length,
      rejected: issues.filter((issue) => issue.status === 'Rejected').length,
      in_progress: issues.filter((issue) => issue.status === 'In Progress').length,
      avg_close_days: avgCloseDays === null ? null : Number(avgCloseDays.toFixed(1)),
      measured_closures: measured.length,
      by_category: byCategory,
    });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET api/issues/queue
// @desc    Triage queue, hardest work first
// @access  Admin
router.get('/queue', auth, admin, async (req, res) => {
  const { status, category, limit = 100 } = req.query;

  try {
    const filter = { ...wardFilter(req.user.wards) };
    if (status) filter.status = status;
    if (category) filter.category = category;

    const issues = await Issue.find(filter)
      .populate('userId', 'username avatarUrl')
      .lean();

    const now = new Date();

    // Triage order: what is late, then what the most people are waiting on,
    // then what has been waiting longest.
    const ranked = issues
      .map((issue) => ({ ...issue, overdue: sla.isOverdue(issue, now) }))
      .sort((a, b) => {
        if (a.overdue !== b.overdue) return a.overdue ? -1 : 1;
        if (b.agreeCount !== a.agreeCount) return b.agreeCount - a.agreeCount;
        return new Date(a.createdAt) - new Date(b.createdAt);
      })
      .slice(0, parseInt(limit));

    const userVotes = await voteMapFor(req.user.id, ranked);

    res.json(
      ranked.map((issue) =>
        serializeIssue(issue, { userVote: userVotes[issue._id.toString()] || null })
      )
    );
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET api/issues/:id
// @desc    Get single issue details
// @access  Public
router.get('/:id', async (req, res) => {
  try {
    const issue = await Issue.findById(req.params.id)
      .populate('userId', 'username avatarUrl')
      .lean();
    if (!issue) {
      return res.status(404).json({ message: 'Issue not found' });
    }

    const userId = getUserIdFromRequest(req);
    let userVote = null;
    if (userId) {
      const voteObj = await Vote.findOne({ issueId: issue._id, userId });
      if (voteObj) {
        userVote = voteObj.isAgree ? 'agree' : 'disagree';
      }
    }

    res.json(serializeIssue(issue, { userVote, includeHistory: true }));
  } catch (err) {
    console.error(err.message);
    if (err.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Issue not found' });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   PATCH api/issues/:id/status
// @desc    Move a complaint through its lifecycle
// @access  Admin
router.patch('/:id/status', auth, admin, async (req, res) => {
  const { status, note } = req.body;

  try {
    const allowed = Issue.schema.path('status').enumValues;
    if (!allowed.includes(status)) {
      return res.status(400).json({
        message: `Status must be one of: ${allowed.join(', ')}`,
      });
    }

    const issue = await Issue.findById(req.params.id);
    if (!issue) {
      return res.status(404).json({ message: 'Issue not found' });
    }

    if (!officerCoversWard(req.user.wards, issue.ward)) {
      return res.status(403).json({
        message: 'This complaint is outside the wards you are assigned to',
      });
    }

    if (issue.status === status) {
      return res.status(200).json(serializeIssue(issue, { includeHistory: true }));
    }

    const now = new Date();
    issue.status = status;
    issue.updatedAt = now;
    issue.statusHistory.push({
      status,
      changedBy: req.user.id,
      changedAt: now,
      note: (note || '').trim(),
    });

    // Stamp the first closure, and clear it if the complaint is reopened, so
    // resolution-time metrics measure the run that actually closed it.
    if (sla.TERMINAL_STATUSES.includes(status)) {
      issue.closedAt = issue.closedAt || now;
    } else {
      issue.closedAt = null;
    }

    await issue.save();

    res.json(serializeIssue(issue, { includeHistory: true }));
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST api/issues/:id/vote
// @desc    Vote Agree/Disagree on an issue
// @access  Private
router.post('/:id/vote', auth, async (req, res) => {
  const { isAgree } = req.body;

  try {
    const issue = await Issue.findById(req.params.id);
    if (!issue) {
      return res.status(404).json({ message: 'Issue not found' });
    }

    // Check if vote exists
    let vote = await Vote.findOne({ issueId: issue.id, userId: req.user.id });

    if (vote) {
      // Update existing vote
      vote.isAgree = isAgree;
      vote.updatedAt = Date.now();
      await vote.save();
    } else {
      // Cast new vote
      vote = new Vote({
        issueId: issue.id,
        userId: req.user.id,
        isAgree,
      });
      await vote.save();
    }

    // Recalculate totals
    const agreeCount = await Vote.countDocuments({ issueId: issue.id, isAgree: true });
    const disagreeCount = await Vote.countDocuments({ issueId: issue.id, isAgree: false });

    issue.agreeCount = agreeCount;
    issue.disagreeCount = disagreeCount;
    await issue.save();

    res.json({
      success: true,
      agreeCount,
      disagreeCount,
    });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error in voting' });
  }
});

// @route   POST api/issues/:id/upvote
// @desc    Toggle legacy upvote
// @access  Private
router.post('/:id/upvote', auth, async (req, res) => {
  try {
    const issue = await Issue.findById(req.params.id);
    if (!issue) {
      return res.status(404).json({ message: 'Issue not found' });
    }

    let upvote = await Upvote.findOne({ issueId: issue.id, userId: req.user.id });

    if (upvote) {
      // Toggle off - delete
      await upvote.deleteOne();
      res.json({ toggled: false });
    } else {
      // Toggle on - insert
      upvote = new Upvote({
        issueId: issue.id,
        userId: req.user.id,
      });
      await upvote.save();
      res.json({ toggled: true });
    }
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error toggling upvote' });
  }
});

// @route   GET api/issues/:id/upvote/count
// @desc    Get aggregate legacy upvotes count
// @access  Public
router.get('/:id/upvote/count', async (req, res) => {
  try {
    const count = await Upvote.countDocuments({ issueId: req.params.id });
    res.json({ count });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
