/**
 * One-time migration script: backfills the GeoJSON `location` field
 * on every Issue document that has latitude/longitude but no location.
 *
 * Usage:  node server/migrate_location.js
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const mongoose = require('mongoose');
const Issue = require('./models/Issue');

const migrate = async () => {
  try {
    if (!process.env.MONGO_URI) {
      throw new Error('MONGO_URI is not defined in your environment variables.');
    }

    const conn = await mongoose.connect(process.env.MONGO_URI, {
      dbName: 'civic_connect',
    });
    console.log(`Connected to MongoDB: ${conn.connection.host}`);

    // Find issues that either have no location field or have default [0,0] coordinates
    // but have valid latitude/longitude values
    const issues = await Issue.find({
      latitude: { $exists: true },
      longitude: { $exists: true },
      $or: [
        { location: { $exists: false } },
        { 'location.coordinates': [0, 0] },
      ],
    });

    console.log(`Found ${issues.length} issues to migrate.`);

    let migratedCount = 0;
    for (const issue of issues) {
      if (issue.latitude == null || issue.longitude == null) continue;
      if (issue.latitude === 0 && issue.longitude === 0) continue;

      issue.location = {
        type: 'Point',
        coordinates: [issue.longitude, issue.latitude], // GeoJSON: [lng, lat]
      };
      await issue.save();
      migratedCount++;
    }

    console.log(`Migration complete. Updated ${migratedCount} issues.`);
    mongoose.connection.close();
  } catch (error) {
    console.error('Migration error:', error);
    process.exit(1);
  }
};

migrate();
