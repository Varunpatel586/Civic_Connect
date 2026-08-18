const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Comment = require('../models/Comment');
const Issue = require('../models/Issue');

// @route   GET api/comments/issue/:issueId
// @desc    Get all comments for an issue
// @access  Public
router.get('/issue/:issueId', async (req, res) => {
  try {
    const comments = await Comment.find({ issueId: req.params.issueId })
      .populate('userId', 'username avatarUrl createdAt')
      .sort({ createdAt: -1 });

    const formatted = comments.map((comment) => ({
      id: comment._id.toString(),
      issue_id: comment.issueId.toString(),
      user_id: comment.userId ? comment.userId._id.toString() : '',
      content: comment.content,
      created_at: comment.createdAt,
      user: {
        id: comment.userId ? comment.userId._id.toString() : '',
        username: comment.userId ? comment.userId.username : 'Unknown',
        email: '',
        role: 'user',
        avatar_url: comment.userId ? comment.userId.avatarUrl : null,
        created_at: comment.userId ? comment.userId.createdAt : comment.createdAt,
      },
    }));

    res.json(formatted);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   POST api/comments/issue/:issueId
// @desc    Post a comment to an issue
// @access  Private
router.post('/issue/:issueId', auth, async (req, res) => {
  const { content } = req.body;

  try {
    if (!content || content.trim() === '') {
      return res.status(400).json({ message: 'Comment content cannot be empty' });
    }

    const issue = await Issue.findById(req.params.issueId);
    if (!issue) {
      return res.status(404).json({ message: 'Issue not found' });
    }

    const newComment = new Comment({
      issueId: req.params.issueId,
      userId: req.user.id,
      content: content.trim(),
    });

    let comment = await newComment.save();
    
    // Populate user info for the response
    comment = await comment.populate('userId', 'username avatarUrl createdAt');

    const formatted = {
      id: comment._id.toString(),
      issue_id: comment.issueId.toString(),
      user_id: comment.userId ? comment.userId._id.toString() : '',
      content: comment.content,
      created_at: comment.createdAt,
      user: {
        id: comment.userId ? comment.userId._id.toString() : '',
        username: comment.userId ? comment.userId.username : 'Unknown',
        email: '',
        role: 'user',
        avatar_url: comment.userId ? comment.userId.avatarUrl : null,
        created_at: comment.userId ? comment.userId.createdAt : comment.createdAt,
      },
    };

    res.status(201).json(formatted);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   PUT api/comments/:id
// @desc    Update a comment
// @access  Private
router.put('/:id', auth, async (req, res) => {
  const { content } = req.body;

  try {
    let comment = await Comment.findById(req.params.id);
    if (!comment) {
      return res.status(404).json({ message: 'Comment not found' });
    }

    // Verify ownership
    if (comment.userId.toString() !== req.user.id) {
      return res.status(401).json({ message: 'User not authorized to edit this comment' });
    }

    comment.content = content.trim();
    await comment.save();

    comment = await comment.populate('userId', 'username avatarUrl email role createdAt');

    const formatted = {
      id: comment._id.toString(),
      issue_id: comment.issueId.toString(),
      user_id: comment.userId ? comment.userId._id.toString() : '',
      content: comment.content,
      created_at: comment.createdAt,
      user: {
        id: comment.userId ? comment.userId._id.toString() : '',
        username: comment.userId ? comment.userId.username : 'Unknown',
        email: comment.userId ? comment.userId.email : '',
        role: comment.userId ? comment.userId.role : 'user',
        avatar_url: comment.userId ? comment.userId.avatarUrl : null,
        created_at: comment.userId ? comment.userId.createdAt : comment.createdAt,
      },
    };

    res.json(formatted);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

// @route   DELETE api/comments/:id
// @desc    Delete a comment
// @access  Private
router.delete('/:id', auth, async (req, res) => {
  try {
    const comment = await Comment.findById(req.params.id);
    if (!comment) {
      return res.status(404).json({ message: 'Comment not found' });
    }

    // Verify ownership
    if (comment.userId.toString() !== req.user.id) {
      return res.status(401).json({ message: 'User not authorized to delete this comment' });
    }

    await comment.deleteOne();
    res.json({ message: 'Comment removed successfully' });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server error');
  }
});

module.exports = router;
