const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const auth = require('../middleware/auth');
const admin = require('../middleware/admin');
const Issue = require('../models/Issue');
const Vote = require('../models/Vote');
const Upvote = require('../models/Upvote');
const jwt = require('jsonwebtoken');
const sla = require('../config/sla');
const config = require('../config/env');
const { wardFilter, officerCoversWard } = require('../config/wards');
const issueController = require('../controllers/issueController');
const notificationService = require('../services/notificationService');
const verification = require('../services/verification');
const imageStore = require('../services/imageStore');
const absoluteStoredUrl = require('../utils/absoluteStoredUrl');
const { requestBaseUrl } = require('../utils/requestBaseUrl');
const { referenceFor } = require('../config/reference');

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

// Multer holds photographs in memory only. Storage happens in imageStore,
// which compresses the bytes and writes them into MongoDB GridFS — nothing
// is ever written to the container filesystem.
const storage = multer.memoryStorage();
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
/** The photo from the last time an officer claimed this was fixed. */
const latestResolutionPhoto = (issue) => {
  const history = issue.statusHistory || [];
  for (let i = history.length - 1; i >= 0; i -= 1) {
    if (history[i].status === 'Resolved' && history[i].photoUrl) {
      return history[i].photoUrl;
    }
  }
  return '';
};

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
    image_url: absoluteStoredUrl(issue.imageUrl),
    image_urls: (issue.imageUrls || []).map((url) => absoluteStoredUrl(url)),
    latitude: issue.latitude,
    longitude: issue.longitude,
    address: issue.address,
    ward: issue.ward || null,
    status: issue.status,
    report_count: issue.reportCount || 1,
    agree_count: issue.agreeCount,
    disagree_count: issue.disagreeCount,
    user_vote: userVote,
    due_at: sla.dueDate(issue),
    is_overdue: sla.isOverdue(issue),
    closed_at: issue.closedAt || null,
    // Who may answer the verification question. Clustering means this can
    // be several accounts, so user_id alone is not enough for the client.
    reporter_ids: (issue.reporters && issue.reporters.length > 0
      ? issue.reporters
      : [issue.userId]
    ).filter(Boolean).map((r) => r.toString()),
    reference: referenceFor(issue),
    // The photo attached to the most recent Resolved claim, which is what
    // the citizen is shown beside the original when asked to confirm.
    resolution_photo_url: absoluteStoredUrl(latestResolutionPhoto(issue)),
    verification_state: (issue.verification && issue.verification.state) || 'none',
    verification_due_by: (issue.verification && issue.verification.dueBy) || null,
    verification_note: (issue.verification && issue.verification.note) || '',
    verification_evidence_url: absoluteStoredUrl(
      (issue.verification && issue.verification.evidenceUrl) || ''
    ),
    escalated_at: issue.escalatedAt || null,
    reopen_count: issue.reopenCount || 0,
    timestamp: issue.createdAt,
    created_at: issue.createdAt,
    user: {
      username: user ? user.username : 'Unknown',
      avatar_url: user ? absoluteStoredUrl(user.avatarUrl) : null,
    },
  };

  if (includeHistory) {
    payload.status_history = (issue.statusHistory || []).map((entry) => ({
      status: entry.status,
      changed_at: entry.changedAt,
      note: entry.note || '',
      photo_url: absoluteStoredUrl(entry.photoUrl) || '',
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
// @desc    Store a photograph in MongoDB and return the URL it is served at
// @access  Private
router.post('/upload', auth, upload.single('photo'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    const stored = await imageStore.saveImage({
      buffer: req.file.buffer,
      originalname: req.file.originalname,
      mimetype: req.file.mimetype,
    });

    // Built from the host this request arrived on, so a photograph uploaded
    // through Render is stored pointing at Render rather than at a guess.
    const hostUrl = requestBaseUrl(req) || config.apiUrl;
    const fileUrl = `${hostUrl}/uploads/${stored.filename}`;

    res.json({ url: fileUrl });
  } catch (err) {
    console.error('Upload error:', err.message);
    res.status(500).json({ message: 'Server upload error' });
  }
});

// @route   POST api/issues
// @desc    Create new issue
// @access  Private
// Accepts either a JSON payload referencing an already-uploaded URL, or a
// direct multipart upload — multer passes non-multipart bodies through
// untouched, so existing JSON clients are unaffected.
router.post('/', auth, upload.single('photo'), issueController.createIssue);

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

    // Silence is assent: settle any verification windows that have run out
    // before counting, so the numbers below never include limbo rows.
    await verification.settleExpired();
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

    // Silence is assent: settle any verification windows that have run out
    // before counting, so the numbers below never include limbo rows.
    await verification.settleExpired();
    const filter = { ...wardFilter(req.user.wards) };
    if (status) filter.status = status;
    if (category) filter.category = category;

    const issues = await Issue.find(filter)
      .populate('userId', 'username avatarUrl')
      .lean();

    const now = new Date();
    
    // Triage order: Dynamic Priority Score P
    const ranked = issues
      .map((issue) => {
        const N = issue.reportCount || 1;
        const Va = issue.agreeCount || 0;
        const Vd = issue.disagreeCount || 0;
        const Sai = issue.severityScore || 2; // Default if not analyzed
        
        // SLA timing calculation
        const createdAt = issue.createdAt ? new Date(issue.createdAt).getTime() : now.getTime();
        const dueAt = sla.dueDate(issue).getTime();
        const TSlaTotal = dueAt - createdAt;
        const TRemaining = dueAt - now.getTime();
        
        // Decay factor in [0, 1]
        let timeFactor = 0;
        if (TSlaTotal > 0) {
          timeFactor = Math.max(0, (TSlaTotal - TRemaining) / TSlaTotal);
        }
        
        // Prevent Math.log2 from crashing if N is missing/negative
        const wr = 2.5, wv = 1.0, ws = 2.0, wt = 3.0;
        const P = (wr * Math.log2(1 + N)) +
                  (wv * (Va - Vd)) +
                  (ws * Sai) +
                  (wt * timeFactor);

        return { ...issue, priorityScore: P, overdue: sla.isOverdue(issue, now) };
      })
      .sort((a, b) => {
        // High priority score first
        if (b.priorityScore !== a.priorityScore) {
          return b.priorityScore - a.priorityScore;
        }
        return new Date(a.createdAt) - new Date(b.createdAt);
      })
      .slice(0, parseInt(limit));

    const userVotes = await voteMapFor(req.user.id, ranked);

    res.json(
      ranked.map((issue) => {
        const serialized = serializeIssue(issue, { userVote: userVotes[issue._id.toString()] || null });
        serialized.priority_score = issue.priorityScore;
        return serialized;
      })
    );
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET api/issues/nearby-candidates
// @desc    Interactive Proximity Interceptor
router.get('/nearby-candidates', auth, async (req, res) => {
  const { lat, lng, category, radius = 25 } = req.query;

  if (lat === undefined || lng === undefined) {
    return res.status(400).json({ message: 'Latitude and longitude required' });
  }

  const targetLat = Number.parseFloat(lat);
  const targetLng = Number.parseFloat(lng);
  const radiusKm = Number.parseFloat(radius) / 1000.0;
  const EARTH_RADIUS_KM = 6378.1;

  try {
    const filter = {
      status: { $nin: ['Resolved', 'Rejected'] },
      location: {
        $geoWithin: {
          $centerSphere: [[targetLng, targetLat], radiusKm / EARTH_RADIUS_KM],
        },
      },
    };
    if (category) filter.category = category;

    const issues = await Issue.find(filter)
      .sort({ createdAt: -1 })
      .populate('userId', 'username avatarUrl')
      .lean();

    res.json(issues.map((issue) => serializeIssue(issue)));
  } catch (err) {
    console.error('Candidates error:', err);
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
  const { status, note, photo_url: photoUrl } = req.body;

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

    // An officer cannot claim a fix without showing it. Only Resolved is
    // held to this: Rejected is the municipality declining to act, which
    // has nothing to photograph.
    if (status === 'Resolved' && !(photoUrl || '').trim()) {
      return res.status(400).json({
        message: 'A photo of the completed work is required to resolve a complaint',
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
      photoUrl: (photoUrl || '').trim(),
    });

    // Stamp the first closure, and clear it if the complaint is reopened, so
    // resolution-time metrics measure the run that actually closed it.
    if (sla.TERMINAL_STATUSES.includes(status)) {
      issue.closedAt = issue.closedAt || now;
    } else {
      issue.closedAt = null;
    }

    // A claimed fix is not a fix until the person who reported it agrees.
    //
    // Only 'Resolved' opens a verification window. 'Rejected' is the
    // municipality declining to act, which is a decision rather than a claim
    // about the world, so there is nothing for the reporter to contradict.
    if (status === 'Resolved') {
      issue.verification.state = 'pending';
      issue.verification.askedAt = now;
      issue.verification.dueBy = verification.verificationDeadline(now);
      issue.verification.respondedAt = null;
      issue.verification.respondedBy = null;
      issue.verification.note = '';
      issue.verification.evidenceUrl = '';
    } else if (issue.verification.state === 'pending') {
      // Moved off Resolved before anybody answered, so the question is moot.
      issue.verification.state = 'none';
      issue.verification.dueBy = null;
    }

    await issue.save();

    // Everyone who reported it hears about it, not just the original filer:
    // clustering means one complaint can carry several reporters.
    const reporters =
      issue.reporters && issue.reporters.length > 0 ? issue.reporters : [issue.userId];

    const reference = referenceFor(issue);
    const trimmedNote = (note || '').trim();
    const messages = {
      'In Progress': [
        'Work started',
        reference + ' has been picked up by your ward office.',
      ],
      Resolved: [
        'Is this actually fixed?',
        reference + ' was marked resolved. Confirm the fix, or reopen it if the problem is still there.',
      ],
      Rejected: [
        'Complaint closed',
        reference + ' was closed without action' + (trimmedNote ? ': ' + trimmedNote : '.'),
      ],
      Pending: ['Complaint reopened', reference + ' is back in the queue.'],
    };
    const [title, body] = messages[status] || [
      'Complaint updated',
      reference + ' is now ' + status + '.',
    ];

    try {
      await notificationService.fanOut({
        recipients: reporters,
        issue,
        type: status === 'Resolved' ? 'verification_requested' : 'status_changed',
        title,
        body,
        exclude: [req.user.id],
      });
    } catch (notifyErr) {
      // The status change is already committed and is what the officer asked
      // for. A failed notification must not surface as a failed update.
      console.error('[notify] status fan-out failed:', notifyErr.message);
    }

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

const memoryUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_PHOTO_BYTES },
  fileFilter: (req, file, cb) => {
    cb(null, true);
  }
});

// @route   POST api/issues/classify
// @desc    Pre-Submission AI Classification
router.post('/classify', auth, memoryUpload.single('photo'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'No file uploaded' });

    const aiUrl = config.aiServiceUrl || 'http://localhost:8000';
    const formData = new FormData();
    const blob = new Blob([req.file.buffer], { type: req.file.mimetype });
    formData.append('file', blob, req.file.originalname);

    const response = await fetch(`${aiUrl}/api/v1/classify`, {
      method: 'POST',
      body: formData,
    });

    if (!response.ok) {
      return res.status(response.status).json(await response.json());
    }

    res.json(await response.json());
  } catch (err) {
    console.error('Classification error:', err);
    res.status(500).json({ message: 'Server classification error' });
  }
});

// @route   POST api/issues/:id/attach-evidence
// @desc    Append user photo to existing issue
router.post('/:id/attach-evidence', auth, async (req, res) => {
  const { imageUrls } = req.body;
  
  if (!imageUrls || !imageUrls.length) {
    return res.status(400).json({ message: 'imageUrls array required' });
  }

  try {
    const issue = await Issue.findById(req.params.id);
    if (!issue) return res.status(404).json({ message: 'Issue not found' });

    issue.imageUrls.push(...imageUrls);
    
    // Convert ObjectIds to strings for Set comparison
    const existingReporters = issue.reporters.map(id => id.toString());
    if (!existingReporters.includes(req.user.id)) {
      issue.reporters.push(req.user.id);
      issue.reportCount += 1;
    }

    await issue.save();
    res.json(serializeIssue(issue.toObject()));
  } catch (err) {
    console.error('Attach evidence error:', err);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST api/issues/:id/verify
// @desc    The reporter confirms or disputes a claimed fix
// @access  Private — reporters of this complaint only
router.post('/:id/verify', auth, async (req, res) => {
  const { confirmed, note, evidence_url: evidenceUrl } = req.body;

  if (typeof confirmed !== 'boolean') {
    return res.status(400).json({ message: 'confirmed must be true or false' });
  }

  try {
    const issue = await Issue.findById(req.params.id);
    if (!issue) {
      return res.status(404).json({ message: 'Issue not found' });
    }

    // Only the people who reported it get to say whether it is fixed, and
    // clustering means that can be several accounts rather than just `userId`.
    const reporters =
      issue.reporters && issue.reporters.length > 0 ? issue.reporters : [issue.userId];
    const isReporter = reporters.some((r) => String(r) === String(req.user.id));
    if (!isReporter) {
      return res.status(403).json({
        message: 'Only the people who reported this complaint can verify the fix',
      });
    }

    if (issue.verification.state !== 'pending') {
      return res.status(409).json({
        message: 'This complaint is not awaiting verification',
        state: issue.verification.state,
      });
    }

    const now = new Date();
    issue.verification.respondedAt = now;
    issue.verification.respondedBy = req.user.id;
    issue.verification.note = (note || '').trim();

    if (confirmed) {
      // Status stays Resolved and closedAt stands: the officer was right.
      issue.verification.state = 'confirmed';
    } else {
      issue.verification.state = 'disputed';
      issue.verification.evidenceUrl = (evidenceUrl || '').trim();

      // The fix did not hold, so the complaint goes back into the queue. The
      // SLA clock is deliberately not reset — it measures time from report to
      // confirmed fix, and a dispute is proof it was never fixed — which makes
      // a reopened complaint overdue by construction and sorts it to the top.
      issue.status = 'In Progress';
      issue.closedAt = null;
      issue.escalatedAt = now;
      issue.reopenCount = (issue.reopenCount || 0) + 1;
      issue.statusHistory.push({
        status: 'In Progress',
        changedBy: req.user.id,
        changedAt: now,
        note: issue.verification.note || 'Reporter disputed the claimed fix',
      });
    }

    issue.updatedAt = now;
    await issue.save();

    if (!confirmed) {
      // Tell the officer who claimed the fix that it was rejected. Walking the
      // history backwards finds whoever last set it Resolved.
      const claimer = [...issue.statusHistory]
        .reverse()
        .find((e) => e.status === 'Resolved' && e.changedBy);

      try {
        await notificationService.fanOut({
          recipients: claimer ? [claimer.changedBy] : [],
          issue,
          type: 'verification_disputed',
          title: 'Reported fix rejected',
          body:
            referenceFor(issue) +
            ' was reopened by the reporter and is now escalated.',
          exclude: [req.user.id],
        });
      } catch (notifyErr) {
        console.error('[notify] dispute fan-out failed:', notifyErr.message);
      }
    }

    res.json(serializeIssue(issue, { includeHistory: true }));
  } catch (err) {
    console.error('Verify error:', err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
