const mongoose = require('mongoose');
const config = require('./env');
const { backfillIssues } = require('./backfill');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(config.mongoUri, {
      dbName: 'civic_connect'
    });
    console.log(`MongoDB Connected: ${conn.connection.host}`);

    // Idempotent; a no-op once every document carries the current fields.
    await backfillIssues();
  } catch (error) {
    console.error(`MongoDB Connection Error: ${error.message}`);
    process.exit(1);
  }
};

module.exports = connectDB;
