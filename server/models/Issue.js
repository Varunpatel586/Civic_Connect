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
    enum: ['pothole', 'street_light', 'water', 'electricity', 'garbage', 'road', 'drainage', 'other', 'Potholes & Road Damage', 'Garbage Pile-ups', 'Broken Street Lights'],
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
  // Clustered Multi-Reporter and Multi-Image Support
  reporters: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  }],
  imageUrls: [{
    type: String,
    required: true
  }],
  reportCount: {
    type: Number,
    default: 1
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
  // GeoJSON coordinate format for geospatial indexing
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
      required: true
    },
    coordinates: {
      type: [Number], // Format: [longitude, latitude] -> NOTE: GeoJSON requires Longitude first!
      required: true
    }
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
  agreeCount: { type: Number, default: 0 },
  disagreeCount: { type: Number, default: 0 },
  slaDeadline: { type: Date }
}, { timestamps: true });

/**
 * Keeps the GeoJSON point and the ward in step with the flat fields.
 *
 * Runs on validate rather than save so it also applies to documents built for
 * `insertMany`, which skips save hooks.
 */
IssueSchema.pre('validate', function syncDerivedFields(next) {
  if (this.reporters && this.reporters.length > 0 && !this.userId) {
    this.userId = this.reporters[0];
  }
  if (this.imageUrls && this.imageUrls.length > 0 && !this.imageUrl) {
    this.imageUrl = this.imageUrls[0];
  }

  if (this.location && this.location.coordinates && this.location.coordinates.length === 2) {
    this.longitude = this.location.coordinates[0];
    this.latitude = this.location.coordinates[1];
  } else if (typeof this.latitude === 'number' && typeof this.longitude === 'number') {
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

// Crucial: 2dsphere index for radius proximity search
IssueSchema.index({ location: '2dsphere' });
IssueSchema.index({ category: 1, status: 1 });
IssueSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model('Issue', IssueSchema);
