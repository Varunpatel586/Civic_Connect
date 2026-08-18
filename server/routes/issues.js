const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const auth = require('../middleware/auth');
const Issue = require('../models/Issue');
const Vote = require('../models/Vote');
const Upvote = require('../models/Upvote');

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
    const ext = path.extname(file.originalname);
    cb(null, 'photo-' + uniqueSuffix + ext);
  },
});
const upload = multer({ storage: storage });

// Helper to calculate distance in KM
const getDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - c));
  if (isNaN(c)) return 0;
  return R * c;
};

// @route   POST api/issues/upload
// @desc    Upload file to server storage
// @access  Private
router.post('/upload', auth, upload.single('photo'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    const hostUrl = process.env.API_URL || 'http://localhost:5000';
    const fileUrl = `${hostUrl}/uploads/${req.file.filename}`;

    res.json({ url: fileUrl });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server upload error');
  }
});

// @route   POST api/issues
// @desc    Create new issue
// @access  Private
router.post('/', auth, async (req, res) => {
  const { title, description, category, imageUrl, imageUrls, latitude, longitude, address } = req.body;

  try {
    const newIssue = new Issue({
      userId: req.user.id,
      title: title || `${category.replace('_', ' ').toUpperCase()}`,
      description,
      category,
      imageUrl,
      imageUrls: imageUrls || [imageUrl],
      latitude: parseFloat(latitude) || 0.0,
      longitude: parseFloat(longitude) || 0.0,
      address,
    });

    const issue = await newIssue.save();
    res.status(201).json(issue);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   GET api/issues/nearby
// @desc    Fetch issues near a location
// @access  Public
router.get('/nearby', async (req, res) => {
  const { lat, lng, radius_km = 5.0, limit = 50 } = req.query;

  if (!lat || !lng) {
    return res.status(400).json({ message: 'Latitude and longitude are required' });
  }

  const targetLat = parseFloat(lat);
  const targetLng = parseFloat(lng);
  const radius = parseFloat(radius_km);
  const maxLimit = parseInt(limit);

  try {
    // In a production app, use MongoDB 2dsphere indexing & $near or $geoWithin.
    // For simple and reliable queries, retrieve issues and calculate distance in Javascript:
    const allIssues = await Issue.find().populate('userId', 'username avatarUrl').lean();

    const nearby = allIssues
      .map((issue) => {
        // Calculate distance manually
        const distance = getDistance(targetLat, targetLng, issue.latitude, issue.longitude);
        return { ...issue, distance };
      })
      // Filter by radius boundary (default 5.0 km)
      .filter((issue) => issue.distance <= radius)
      // Sort closest first or newest first
      .sort((a, b) => b.createdAt - a.createdAt)
      .slice(0, maxLimit);

    // Map fields to match Supabase expectations (agree_count, disagree_count, etc.)
    const formatted = nearby.map((issue) => ({
      id: issue._id.toString(),
      user_id: issue.userId ? issue.userId._id.toString() : '',
      title: issue.title,
      category: issue.category,
      description: issue.description,
      image_url: issue.imageUrl,
      image_urls: issue.imageUrls,
      latitude: issue.latitude,
      longitude: issue.longitude,
      address: issue.address,
      status: issue.status,
      agree_count: issue.agreeCount,
      disagree_count: issue.disagreeCount,
      timestamp: issue.createdAt,
      created_at: issue.createdAt,
      user: {
        username: issue.userId ? issue.userId.username : 'Unknown',
        avatar_url: issue.userId ? issue.userId.avatarUrl : null,
      },
    }));

    res.json(formatted);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   GET api/issues/user
// @desc    Get current user's issues
// @access  Private
router.get('/user', auth, async (req, res) => {
  try {
    const issues = await Issue.find({ userId: req.user.id })
      .populate('userId', 'username avatarUrl')
      .sort({ createdAt: -1 });

    const formatted = issues.map((issue) => ({
      id: issue._id.toString(),
      user_id: issue.userId ? issue.userId._id.toString() : '',
      title: issue.title,
      category: issue.category,
      description: issue.description,
      image_url: issue.imageUrl,
      image_urls: issue.imageUrls,
      latitude: issue.latitude,
      longitude: issue.longitude,
      address: issue.address,
      status: issue.status,
      agree_count: issue.agreeCount,
      disagree_count: issue.disagreeCount,
      timestamp: issue.createdAt,
      created_at: issue.createdAt,
    }));

    res.json(formatted);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   GET api/issues/:id
// @desc    Get single issue details
// @access  Public
router.get('/:id', async (req, res) => {
  try {
    const issue = await Issue.findById(req.params.id).populate('userId', 'username avatarUrl');
    if (!issue) {
      return res.status(404).json({ message: 'Issue not found' });
    }

    const formatted = {
      id: issue._id.toString(),
      user_id: issue.userId ? issue.userId._id.toString() : '',
      title: issue.title,
      category: issue.category,
      description: issue.description,
      image_url: issue.imageUrl,
      image_urls: issue.imageUrls,
      latitude: issue.latitude,
      longitude: issue.longitude,
      address: issue.address,
      status: issue.status,
      agree_count: issue.agreeCount,
      disagree_count: issue.disagreeCount,
      timestamp: issue.createdAt,
      created_at: issue.createdAt,
      user: {
        username: issue.userId ? issue.userId.username : 'Unknown',
        avatar_url: issue.userId ? issue.userId.avatarUrl : null,
      },
    };

    res.json(formatted);
  } catch (err) {
    console.error(err.message);
    if (err.kind === 'ObjectId') {
      return res.status(404).json({ message: 'Issue not found' });
    }
    res.status(500).send('Server error');
  }
});

// @route   PATCH api/issues/:id/status
// @desc    Update issue status (Admin only in production)
// @access  Private
router.patch('/:id/status', auth, async (req, res) => {
  const { status } = req.body;

  try {
    const issue = await Issue.findById(req.params.id);
    if (!issue) {
      return res.status(404).json({ message: 'Issue not found' });
    }

    issue.status = status;
    issue.updatedAt = Date.now();
    await issue.save();

    res.json(issue);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
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
    res.status(500).send('Server error in voting');
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
    res.status(500).send('Server error toggling upvote');
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
    res.status(500).send('Server error');
  }
});

module.exports = router;
