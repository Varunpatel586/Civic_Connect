const mongoose = require('mongoose');

const UpvoteSchema = new mongoose.Schema({
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
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// Ensure a user can only upvote once per issue
UpvoteSchema.index({ issueId: 1, userId: 1 }, { unique: true });

module.exports = mongoose.model('Upvote', UpvoteSchema);
