const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const auth = require('../middleware/auth');
const User = require('../models/User');

const JWT_SECRET = process.env.JWT_SECRET || 'super_secret_jwt_key_civic_connect_123';

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
    res.status(500).send('Server error');
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
    res.status(500).send('Server error');
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
    res.status(500).send('Server error');
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
    res.status(500).send('Server error');
  }
});

// @route   POST api/auth/google
// @desc    OAuth with Google
// @access  Public
router.post('/google', async (req, res) => {
  const { idToken } = req.body;

  try {
    if (!idToken) {
      return res.status(400).json({ message: 'ID Token is required' });
    }

    // In production, verify Google ID token using: google-auth-library
    // For demonstration and testing, decode token payload safely or mock Google user retrieval:
    let email, username, avatarUrl;
    
    // Simple verification mock
    if (idToken.startsWith('eyJ')) { // standard JWT signature header
      const base64Url = idToken.split('.')[1];
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
      const jsonPayload = decodeURIComponent(
        Buffer.from(base64, 'base64')
          .toString()
          .split('')
          .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
          .join('')
      );
      const decodedToken = JSON.parse(jsonPayload);
      email = decodedToken.email;
      username = decodedToken.name || email.split('@')[0];
      avatarUrl = decodedToken.picture;
    } else {
      // Mocked callback test details
      email = 'google_user@gmail.com';
      username = 'GoogleUser';
      avatarUrl = null;
    }

    let user = await User.findOne({ email });

    if (!user) {
      // Create user
      user = new User({
        username: username.replace(/\s+/g, '').toLowerCase() + Math.floor(Math.random() * 1000),
        email,
        password: await bcrypt.hash(Math.random().toString(36), 10), // Random placeholder password
        avatarUrl,
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
    res.status(500).send('Server error in Google Sign-In');
  }
});

module.exports = router;
