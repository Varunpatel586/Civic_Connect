const mongoose = require('mongoose');

const VoteSchema = new mongoose.Schema({
  issueId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Issue',
    required: true,
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  isAgree: {
    type: Boolean,
    required: true,
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

// Ensure a user can only vote once per issue
VoteSchema.index({ issueId: 1, userId: 1 }, { unique: true });

module.exports = mongoose.model('Vote', VoteSchema);
