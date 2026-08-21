const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const auth = require('../middleware/auth');
const User = require('../models/User');
const { OAuth2Client } = require('google-auth-library');
const config = require('../config/env');

/**
 * Client IDs this server will accept Google tokens for.
 *
 * Android, iOS and web each get their own OAuth client, so this is a list.
 * Set GOOGLE_CLIENT_IDS in .env as a comma-separated string.
 */
const GOOGLE_CLIENT_IDS = config.googleClientIds;

// Null when nothing is configured, which makes /google refuse rather than
// fall back to trusting the caller.
const googleClient = GOOGLE_CLIENT_IDS.length > 0 ? new OAuth2Client() : null;

const JWT_SECRET = config.jwtSecret;

// Generate Token
const generateToken = (user) => {
  const payload = {
    user: {
      id: user.id,
      username: user.username,
      email: user.email,
      role: user.role,
    },
  };
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
};

// @route   POST api/auth/signup
// @desc    Register user
// @access  Public
router.post('/signup', async (req, res) => {
  const { username, email, password } = req.body;

  try {
    let user = await User.findOne({ email });
    if (user) {
      return res.status(400).json({ message: 'Email is already registered' });
    }

    user = await User.findOne({ username });
    if (user) {
      return res.status(400).json({ message: 'Username is already taken' });
    }

    user = new User({
      username,
      email,
      password,
    });

    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(password, salt);

    await user.save();

    const token = generateToken(user);
    res.status(201).json({
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
      },
    });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST api/auth/login
// @desc    Authenticate user & get token
// @access  Public
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  try {
    let user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: 'Invalid email or password' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid email or password' });
    }

    const token = generateToken(user);
    res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
      },
    });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   GET api/auth/profile
// @desc    Get user profile
// @access  Private
router.get('/profile', auth, async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.json({
      id: user.id,
      username: user.username,
      email: user.email,
      role: user.role,
      avatarUrl: user.avatarUrl,
      createdAt: user.createdAt,
    });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   PUT api/auth/profile
// @desc    Update user profile
// @access  Private
router.put('/profile', auth, async (req, res) => {
  const { username, fullName, avatarUrl } = req.body;

  try {
    let user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (username && username !== user.username) {
      const usernameExists = await User.findOne({ username });
      if (usernameExists) {
        return res.status(400).json({ message: 'Username is already taken' });
      }
      user.username = username;
    }

    if (avatarUrl !== undefined) user.avatarUrl = avatarUrl;
    user.updatedAt = Date.now();

    await user.save();
    res.json({ message: 'Profile updated successfully' });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ message: 'Server error' });
  }
});

// @route   POST api/auth/google
// @desc    Exchange a Google ID token for a session
// @access  Public
router.post('/google', async (req, res) => {
  const { idToken } = req.body;

  if (!idToken) {
    return res.status(400).json({ message: 'ID Token is required' });
  }

  // Fail closed. The previous implementation base64-decoded the token body and
  // trusted whatever email it found, which let anyone sign in as anyone.
  if (!googleClient) {
    return res.status(503).json({
      message:
        'Google sign-in is not configured on this server. Set GOOGLE_CLIENT_IDS in .env.',
    });
  }

  try {
    let payload;
    try {
      const ticket = await googleClient.verifyIdToken({
        idToken,
        audience: GOOGLE_CLIENT_IDS,
      });
      payload = ticket.getPayload();
    } catch (verifyError) {
      console.warn('Rejected Google ID token:', verifyError.message);
      return res.status(401).json({ message: 'Google sign-in could not be verified' });
    }

    // Google sets this false for addresses it has not confirmed; accepting one
    // would let someone claim an address they do not control.
    if (!payload || !payload.email || payload.email_verified !== true) {
      return res
        .status(401)
        .json({ message: 'Google account has no verified email address' });
    }

    const email = payload.email.toLowerCase();
    let user = await User.findOne({ email });

    if (!user) {
      user = new User({
        username: await buildUniqueUsername(payload.name || email.split('@')[0]),
        email,
        // Placeholder: this account signs in through Google, not a password.
        password: await bcrypt.hash(crypto.randomBytes(32).toString('hex'), 10),
        avatarUrl: payload.picture || null,
      });
      await user.save();
    }

    const token = generateToken(user);
    res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error in Google Sign-In' });
  }
});

/**
 * Derives a free username from a Google display name.
 *
 * Checks the database rather than appending a random number and hoping, so
 * signup cannot fail on a unique-index collision.
 */
async function buildUniqueUsername(seed) {
  const base =
    seed
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '')
      .slice(0, 20) || 'citizen';

  if (!(await User.exists({ username: base }))) return base;

  for (let suffix = 1; suffix < 1000; suffix++) {
    const candidate = `${base}${suffix}`;
    if (!(await User.exists({ username: candidate }))) return candidate;
  }

  return `${base}${crypto.randomBytes(4).toString('hex')}`;
}

module.exports = router;
