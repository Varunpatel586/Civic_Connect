const Issue = require('../models/Issue');
const { wardFromAddress } = require('./wards');

/**
 * Brings older complaints up to the current schema.
 *
 * Documents written before the GeoJSON `location` field existed are invisible
 * to `$geoWithin`, so without this the feed and map would silently omit them —
 * the worst kind of failure, because everything still looks like it works.
 *
 * Idempotent and cheap: it only touches documents actually missing a field, so
 * running it on every boot costs one indexed count query once migrated.
 */
async function backfillIssues({ log = console.log } = {}) {
  const needsLocation = await Issue.countDocuments({
    'location.coordinates': { $exists: false },
  });
  const needsWard = await Issue.countDocuments({
    ward: null,
    address: { $nin: [null, ''] },
  });

  if (needsLocation === 0 && needsWard === 0) {
    return { location: 0, ward: 0 };
  }

  log(`Backfilling ${needsLocation} location(s) and ${needsWard} ward(s)...`);

  let locationsWritten = 0;
  let wardsWritten = 0;

  // Cursor rather than find().  A migration should not depend on the whole
  // collection fitting in memory, even when today it would.
  const cursor = Issue.find({
    $or: [
      { 'location.coordinates': { $exists: false } },
      { ward: null, address: { $nin: [null, ''] } },
    ],
  }).cursor();

  for (let issue = await cursor.next(); issue != null; issue = await cursor.next()) {
    const update = {};

    // Not `!issue.location`: Mongoose fills that in from the schema default
    // when hydrating, so an unmigrated document still presents a truthy object
    // with no coordinates inside it. The coordinates are the real signal.
    const hasPoint =
      Array.isArray(issue.location && issue.location.coordinates) &&
      issue.location.coordinates.length === 2;

    if (
      !hasPoint &&
      typeof issue.latitude === 'number' &&
      typeof issue.longitude === 'number'
    ) {
      update.location = {
        type: 'Point',
        coordinates: [issue.longitude, issue.latitude],
      };
      locationsWritten++;
    }

    if (!issue.ward && issue.address) {
      const ward = wardFromAddress(issue.address);
      if (ward) {
        update.ward = ward;
        wardsWritten++;
      }
    }

    if (Object.keys(update).length > 0) {
      await Issue.updateOne({ _id: issue._id }, { $set: update });
    }
  }

  log(`Backfill complete: ${locationsWritten} location(s), ${wardsWritten} ward(s).`);
  return { location: locationsWritten, ward: wardsWritten };
}

module.exports = { backfillIssues };
