const mongoose = require('mongoose');

const IssueSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  title: {
    type: String,
    required: true,
    trim: true,
  },
  category: {
    type: String,
    required: true,
    enum: ['pothole', 'street_light', 'water', 'electricity', 'garbage', 'road', 'drainage', 'other'],
    default: 'other',
  },
  description: {
    type: String,
    default: '',
  },
  imageUrl: {
    type: String,
    required: true,
  },
  imageUrls: {
    type: [String],
    default: [],
  },
  latitude: {
    type: Number,
    required: true,
  },
  longitude: {
    type: Number,
    required: true,
  },
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      required: true,
    },
  },
  address: {
    type: String,
    default: '',
  },
  status: {
    type: String,
    enum: ['Pending', 'In Progress', 'Resolved', 'Rejected'],
    default: 'Pending',
  },
  agreeCount: {
    type: Number,
    default: 0,
  },
  disagreeCount: {
    type: Number,
    default: 0,
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

// GeoJSON 2dsphere index for efficient geospatial queries ($geoWithin, $near, etc.)
IssueSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('Issue', IssueSchema);
