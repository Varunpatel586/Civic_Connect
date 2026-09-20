const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    lowercase: true,
  },
  password: {
    type: String,
    required: true,
  },
  role: {
    type: String,
    enum: ['user', 'admin'],
    default: 'user',
  },
  avatarUrl: {
    type: String,
    default: null,
  },
  // Wards this officer is answerable for. Empty means every ward, which keeps
  // existing admin accounts working and makes scoping opt-in.
  wards: {
    type: [String],
    default: [],
  },
  // Registered FCM devices for this account. One user can have several
  // (phone, tablet, a reinstall that issued a fresh token), so this is a set
  // rather than a single field. Tokens FCM reports as permanently invalid are
  // pruned on the next send.
  deviceTokens: {
    type: [String],
    default: [],
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('User', UserSchema);
