const mongoose = require('mongoose');
const { wardFromAddress } = require('../config/wards');

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
  address: {
    type: String,
    default: '',
  },
  // GeoJSON mirror of latitude/longitude, kept in sync by the hook below.
  // Proximity search needs this shape; the flat pair stays because every
  // existing client reads it.
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
    },
    coordinates: {
      type: [Number], // [longitude, latitude] — GeoJSON order, not lat/lng
      default: undefined,
    },
  },
  // Derived from the geocoded address. Scopes the municipal queue so an officer
  // sees the complaints they are answerable for.
  ward: {
    type: String,
    default: null,
    index: true,
  },
  status: {
    type: String,
    enum: ['Pending', 'In Progress', 'Resolved', 'Rejected'],
    default: 'Pending',
  },
  // Every state this complaint has passed through, oldest first. Drives the
  // citizen-facing timeline and makes resolution time a measured number rather
  // than an estimate off `updatedAt`.
  statusHistory: {
    type: [
      {
        _id: false,
        status: {
          type: String,
          enum: ['Pending', 'In Progress', 'Resolved', 'Rejected'],
          required: true,
        },
        changedBy: {
          type: mongoose.Schema.Types.ObjectId,
          ref: 'User',
          default: null,
        },
        changedAt: { type: Date, default: Date.now },
        note: { type: String, default: '' },
      },
    ],
    default: [],
  },
  // Set the first time the complaint reaches a terminal state, so closure
  // metrics do not need to walk the history on every query.
  closedAt: {
    type: Date,
    default: null,
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

/**
 * Keeps the GeoJSON point and the ward in step with the flat fields.
 *
 * Runs on validate rather than save so it also applies to documents built for
 * `insertMany`, which skips save hooks.
 */
IssueSchema.pre('validate', function syncDerivedFields(next) {
  if (typeof this.latitude === 'number' && typeof this.longitude === 'number') {
    this.location = {
      type: 'Point',
      coordinates: [this.longitude, this.latitude],
    };
  }

  if (!this.ward && this.address) {
    this.ward = wardFromAddress(this.address);
  }

  next();
});

// Real geospatial index. The previous compound index on the flat pair could not
// answer a proximity query, which is why /nearby used to scan every document.
IssueSchema.index({ location: '2dsphere' });
IssueSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model('Issue', IssueSchema);
