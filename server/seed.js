const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const mongoose = require('mongoose');
const User = require('./models/User');
const Issue = require('./models/Issue');

const seedData = async () => {
  try {
    if (!process.env.MONGO_URI) {
      throw new Error('MONGO_URI is not defined in your environment variables.');
    }

    const conn = await mongoose.connect(process.env.MONGO_URI, {
      dbName: 'civic_connect'
    });
    console.log(`Connected to MongoDB for seeding: ${conn.connection.host}`);

    // 1. Create a Seed User
    const userId = '6a84975f324c0cedbcedd2a3';
    const userExists = await User.findById(userId);
    if (!userExists) {
      const newUser = new User({
        _id: userId,
        username: 'civic_citizen',
        email: 'citizen@civicconnect.org',
        password: '$2a$10$ePzxX8RzhnKa1qkmfDa5oeU0cxurn2kHE8sjcOwgvvUvEf8gpmSNW', // hashes to 'password123'
        role: 'user',
        avatarUrl: 'https://api.dicebear.com/7.x/bottts/svg?seed=civic_citizen',
      });
      await newUser.save();
      console.log('Created seed user: civic_citizen (citizen@civicconnect.org / password123)');
    } else {
      console.log('Seed user already exists.');
    }

    // 2. Define the dummy issue IDs to wipe and replace
    const ids = [
      '66bc2e2a0f8b1c4d4b123457',
      '66bc2e2a0f8b1c4d4b123458',
      '66bc2e2a0f8b1c4d4b123459',
      '66bc2e2a0f8b1c4d4b12345a'
    ];
    await Issue.deleteMany({ _id: { $in: ids } });

    // Pick API base url. Use API_URL from env or default to http://localhost:5000.
    // If you are using Android emulator, this should eventually resolve to http://10.0.2.2:5000 on the client side.
    const HOST_URL = process.env.API_URL || 'http://localhost:5000';

    const dummyIssues = [
      {
        _id: ids[0],
        userId: userId,
        title: "Severe Pothole on Amphitheatre Pkwy",
        category: "pothole",
        description: "Large pothole in the middle lane causing cars to swerve dangerously. Needs urgent patching.",
        imageUrl: `${HOST_URL}/uploads/pothole_1.webp`,
        imageUrls: [`${HOST_URL}/uploads/pothole_1.webp`],
        latitude: 37.4225,
        longitude: -122.084,
        address: "Amphitheatre Pkwy, Mountain View, CA 94043",
        status: "Pending",
        agreeCount: 8,
        disagreeCount: 1,
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        _id: ids[1],
        userId: userId,
        title: "Deep Pothole near Shoreline Amphitheatre",
        category: "pothole",
        description: "A deep trench-like pothole has opened up after the recent heavy rain. Avoid the shoulder lane.",
        imageUrl: `${HOST_URL}/uploads/pothole_2.jpg`,
        imageUrls: [`${HOST_URL}/uploads/pothole_2.jpg`],
        latitude: 37.4210,
        longitude: -122.085,
        address: "Shoreline Blvd, Mountain View, CA 94043",
        status: "In Progress",
        agreeCount: 15,
        disagreeCount: 0,
        createdAt: new Date(Date.now() - 86400000), // 1 day ago
        updatedAt: new Date()
      },
      {
        _id: ids[2],
        userId: userId,
        title: "Multiple Potholes on Hill Road",
        category: "pothole",
        description: "Severe road deterioration on Hill Road. Multiple deep potholes causing heavy traffic backlog during rush hour.",
        imageUrl: `${HOST_URL}/uploads/pothole_3.jpg`,
        imageUrls: [`${HOST_URL}/uploads/pothole_3.jpg`],
        latitude: 19.0598,
        longitude: 72.8300,
        address: "Hill Road, Bandra West, Mumbai, Maharashtra 400050, India",
        status: "Pending",
        agreeCount: 24,
        disagreeCount: 2,
        createdAt: new Date(Date.now() - 172800000), // 2 days ago
        updatedAt: new Date()
      },
      {
        _id: ids[3],
        userId: userId,
        title: "Pothole at Carter Road Intersection",
        category: "pothole",
        description: "Deep pothole at the main crossing. Highly dangerous for two-wheelers, especially at night due to poor lighting.",
        imageUrl: `${HOST_URL}/uploads/pothole_4.jpg`,
        imageUrls: [`${HOST_URL}/uploads/pothole_4.jpg`],
        latitude: 19.0620,
        longitude: 72.8250,
        address: "Carter Road, Bandra West, Mumbai, Maharashtra 400050, India",
        status: "Resolved",
        agreeCount: 42,
        disagreeCount: 0,
        createdAt: new Date(Date.now() - 604800000), // 7 days ago
        updatedAt: new Date()
      }
    ];

    await Issue.insertMany(dummyIssues);
    console.log('Seeded dummy issues successfully!');
    mongoose.connection.close();
  } catch (error) {
    console.error('Error seeding data:', error);
    process.exit(1);
  }
};

seedData();
