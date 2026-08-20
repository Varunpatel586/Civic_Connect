const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('./models/User');
const Issue = require('./models/Issue');

const DAY = 86400000;
const ago = (days) => new Date(Date.now() - days * DAY);

const CITIZEN_ID = '6a84975f324c0cedbcedd2a3';
const OFFICER_ID = '6a84975f324c0cedbcedd2b7';

const DEMO_PASSWORD = 'password123';

/**
 * Rebuilds the lifecycle a complaint would have accumulated.
 *
 * Seeded rows need a history for the same reason live ones do: the citizen
 * timeline and the closure metrics both read it, and a complaint with no
 * history renders as though nothing ever happened to it.
 */
const historyFor = ({ status, filedAt, closedAt }) => {
  const history = [
    { status: 'Pending', changedBy: CITIZEN_ID, changedAt: filedAt, note: 'Complaint filed' },
  ];

  if (status === 'Pending') return history;

  // Everything that moved on was picked up partway through its wait.
  const pickedUpAt = new Date(
    filedAt.getTime() + ((closedAt || new Date()).getTime() - filedAt.getTime()) / 2
  );
  history.push({
    status: 'In Progress',
    changedBy: OFFICER_ID,
    changedAt: pickedUpAt,
    note: 'Assigned to ward works team',
  });

  if (status === 'In Progress') return history;

  history.push({
    status,
    changedBy: OFFICER_ID,
    changedAt: closedAt,
    note: status === 'Resolved' ? 'Work completed and verified' : 'Outside municipal jurisdiction',
  });

  return history;
};

const upsertUser = async ({ _id, username, email, role, avatarSeed }) => {
  const existing = await User.findById(_id);
  if (existing) {
    // Keep the role current even if the row predates this script.
    if (existing.role !== role) {
      existing.role = role;
      await existing.save();
      console.log(`Updated ${username} role -> ${role}`);
    } else {
      console.log(`User already present: ${username}`);
    }
    return;
  }

  await new User({
    _id,
    username,
    email,
    password: await bcrypt.hash(DEMO_PASSWORD, 10),
    role,
    avatarUrl: `https://api.dicebear.com/7.x/bottts/svg?seed=${avatarSeed}`,
  }).save();

  console.log(`Created ${role}: ${username} (${email} / ${DEMO_PASSWORD})`);
};

const seedData = async () => {
  try {
    if (!process.env.MONGO_URI) {
      throw new Error('MONGO_URI is not defined in your environment variables.');
    }

    const conn = await mongoose.connect(process.env.MONGO_URI, {
      dbName: 'civic_connect',
    });
    console.log(`Connected to MongoDB for seeding: ${conn.connection.host}`);

    await upsertUser({
      _id: CITIZEN_ID,
      username: 'civic_citizen',
      email: 'citizen@civicconnect.org',
      role: 'user',
      avatarSeed: 'civic_citizen',
    });

    await upsertUser({
      _id: OFFICER_ID,
      username: 'ward_officer',
      email: 'officer@civicconnect.gov.in',
      role: 'admin',
      avatarSeed: 'ward_officer',
    });

    const HOST_URL = process.env.API_URL || 'http://localhost:5000';
    // Only four photographs ship with the repo, so they are reused across
    // categories. Swap in real imagery before recording anything.
    const photo = (n) =>
      `${HOST_URL}/uploads/${['pothole_1.webp', 'pothole_2.jpg', 'pothole_3.jpg', 'pothole_4.jpg'][n]}`;

    // Bandra West, Mumbai — a real ward, so reverse-geocoded addresses and the
    // MH state code in complaint references both come out right.
    const BANDRA = { latitude: 19.0596, longitude: 72.8295 };
    const at = (dLat, dLng) => ({
      latitude: BANDRA.latitude + dLat,
      longitude: BANDRA.longitude + dLng,
    });
    const address = (street) =>
      `${street}, Bandra West, 400050, Maharashtra, India`;

    /**
     * The spread is deliberate. Two complaints are past their window so the
     * overdue counter is non-zero and the queue has something at the top; three
     * are resolved with recorded closures so "avg close" is a measured 4.0 days
     * rather than a dash; six categories so the breakdown chart has shape.
     */
    const specs = [
      {
        title: 'Burst water main flooding Sector 12',
        category: 'water', // 2-day window, filed 5 days ago -> overdue
        description:
          'Water has been running down the road for three days. Supply to the whole lane is down and the road surface is starting to give way.',
        street: 'Sector 12 Service Road',
        offset: [0.0021, -0.0018],
        photo: 1,
        status: 'Pending',
        filedDaysAgo: 5,
        agreeCount: 61,
        disagreeCount: 1,
      },
      {
        title: 'No street light on Link Road stretch',
        category: 'street_light', // 3-day window, filed 6 days ago -> overdue
        description:
          'The entire stretch between the junction and the market has been dark for over a week. Unsafe for anyone walking after sunset.',
        street: 'Link Road',
        offset: [-0.0014, 0.0022],
        photo: 3,
        status: 'Pending',
        filedDaysAgo: 6,
        agreeCount: 28,
        disagreeCount: 0,
      },
      {
        title: 'Multiple potholes on Hill Road',
        category: 'pothole',
        description:
          'Severe road deterioration on Hill Road. Multiple deep potholes causing heavy traffic backlog during rush hour.',
        street: 'Hill Road',
        offset: [0.0002, 0.0005],
        photo: 2,
        status: 'Pending',
        filedDaysAgo: 2,
        agreeCount: 24,
        disagreeCount: 2,
      },
      {
        title: 'Deep pothole at Carter Road crossing',
        category: 'pothole',
        description:
          'Deep pothole at the main crossing. Dangerous for two-wheelers, especially at night.',
        street: 'Carter Road',
        offset: [0.0024, -0.0045],
        photo: 3,
        status: 'In Progress',
        filedDaysAgo: 3,
        agreeCount: 15,
        disagreeCount: 0,
      },
      {
        title: 'Garbage uncollected behind the market',
        category: 'garbage',
        description:
          'Collection has not happened for six days. The pile has spread onto the footpath and the smell is severe.',
        street: 'Market Road',
        offset: [-0.0008, -0.0012],
        photo: 0,
        status: 'In Progress',
        filedDaysAgo: 2,
        agreeCount: 12,
        disagreeCount: 1,
      },
      {
        title: 'Blocked storm drain on 4th Lane',
        category: 'drainage',
        description:
          'The drain has been choked since the last spell of rain. Standing water across the lane entrance.',
        street: '4th Lane',
        offset: [0.0011, 0.0031],
        photo: 1,
        status: 'Pending',
        filedDaysAgo: 1,
        agreeCount: 7,
        disagreeCount: 0,
      },
      {
        title: 'Pothole repaired near St Andrews',
        category: 'pothole',
        description: 'Large pothole on the approach road. Patched by the works team.',
        street: 'St Andrews Road',
        offset: [-0.0026, 0.0009],
        photo: 2,
        status: 'Resolved',
        filedDaysAgo: 10,
        closedDaysAgo: 4, // 6 days to close
        agreeCount: 42,
        disagreeCount: 0,
      },
      {
        title: 'Garbage point cleared at Pali Naka',
        category: 'garbage',
        description: 'Overflowing collection point. Cleared and collection schedule restored.',
        street: 'Pali Naka',
        offset: [0.0033, 0.0016],
        photo: 0,
        status: 'Resolved',
        filedDaysAgo: 8,
        closedDaysAgo: 5, // 3 days
        agreeCount: 19,
        disagreeCount: 0,
      },
      {
        title: 'Street light restored on Turner Road',
        category: 'street_light',
        description: 'Two poles out on the eastern footpath. Both fixtures replaced.',
        street: 'Turner Road',
        offset: [-0.0019, -0.0027],
        photo: 3,
        status: 'Resolved',
        filedDaysAgo: 6,
        closedDaysAgo: 3, // 3 days
        agreeCount: 23,
        disagreeCount: 1,
      },
      {
        title: 'Highway shoulder damage past the flyover',
        category: 'road',
        description: 'Shoulder has broken up past the flyover exit.',
        street: 'Western Express Highway',
        offset: [0.0048, 0.0052],
        photo: 2,
        status: 'Rejected',
        filedDaysAgo: 12,
        closedDaysAgo: 9,
        agreeCount: 5,
        disagreeCount: 8,
      },
    ];

    const issues = specs.map((spec, index) => {
      const filedAt = ago(spec.filedDaysAgo);
      const closedAt =
        spec.closedDaysAgo === undefined ? null : ago(spec.closedDaysAgo);

      return {
        _id: new mongoose.Types.ObjectId(
          `66bc2e2a0f8b1c4d4b1234${(index + 16).toString(16).padStart(2, '0')}`
        ),
        userId: CITIZEN_ID,
        title: spec.title,
        category: spec.category,
        description: spec.description,
        imageUrl: photo(spec.photo),
        imageUrls: [photo(spec.photo)],
        ...at(spec.offset[0], spec.offset[1]),
        address: address(spec.street),
        status: spec.status,
        agreeCount: spec.agreeCount,
        disagreeCount: spec.disagreeCount,
        statusHistory: historyFor({ status: spec.status, filedAt, closedAt }),
        closedAt,
        createdAt: filedAt,
        updatedAt: closedAt || filedAt,
      };
    });

    // Rows written by earlier revisions of this script, which used a different
    // id block. Without this they survive alongside the new set and the demo
    // shows a mix of Mumbai and Mountain View complaints.
    const SUPERSEDED_IDS = [
      '66bc2e2a0f8b1c4d4b123457',
      '66bc2e2a0f8b1c4d4b123458',
      '66bc2e2a0f8b1c4d4b123459',
      '66bc2e2a0f8b1c4d4b12345a',
    ];

    const ids = issues.map((issue) => issue._id);
    await Issue.deleteMany({
      _id: { $in: [...ids, ...SUPERSEDED_IDS] },
    });
    await Issue.insertMany(issues);

    const resolved = issues.filter((i) => i.status === 'Resolved');
    const avg =
      resolved.reduce((t, i) => t + (i.closedAt - i.createdAt), 0) /
      resolved.length /
      DAY;

    console.log(`Seeded ${issues.length} complaints in Bandra West, Mumbai.`);
    console.log(
      `  open ${issues.filter((i) => !['Resolved', 'Rejected'].includes(i.status)).length}` +
        ` · resolved ${resolved.length}` +
        ` · avg close ${avg.toFixed(1)}d`
    );
    console.log('');
    console.log('Sign in as:');
    console.log(`  citizen  citizen@civicconnect.org      / ${DEMO_PASSWORD}`);
    console.log(`  officer  officer@civicconnect.gov.in   / ${DEMO_PASSWORD}`);

    await mongoose.connection.close();
  } catch (error) {
    console.error('Error seeding data:', error);
    process.exit(1);
  }
};

seedData();
