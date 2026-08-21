const Issue = require('../models/Issue');
const axios = require('axios');
const path = require('path');
const sla = require('../config/sla');

const config = require('../config/env');

const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:8000';
const CLUSTERING_CATEGORIES = [
  'Potholes & Road Damage', 'Garbage Pile-ups', 'Broken Street Lights',
  'pothole', 'street_light', 'garbage', 'road'
];
const SEARCH_RADIUS_METERS = 15;

exports.createIssue = async (req, res) => {
  try {
    const { title, category, description, address, latitude, longitude } = req.body;
    const userId = req.user.id;
    
    const hostUrl = config.apiUrl;
    let uploadedFile = req.file ? req.file.path : null;
    let uploadedImageUrl = req.file ? `${hostUrl}/uploads/${req.file.filename}` : null;

    if (!uploadedFile) {
      // Fallback: check if the client sent an already-uploaded imageUrl / imageUrls
      const fallbackUrl = req.body.imageUrl || (req.body.imageUrls && req.body.imageUrls[0]);
      if (fallbackUrl) {
        const filename = path.basename(fallbackUrl);
        uploadedImageUrl = `${hostUrl}/uploads/${filename}`;
        // Resolve path to the uploads directory in the server directory
        uploadedFile = path.resolve(__dirname, '../uploads', filename);
      }
    }

    if (!uploadedFile) {
      return res.status(400).json({ error: 'Image proof is required.' });
    }

    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);

    if (isNaN(lat) || isNaN(lng)) {
      return res.status(400).json({ error: 'Latitude and longitude are required and must be valid numbers.' });
    }

    const resolvedTitle = (title || category.replace('_', ' ').toUpperCase())
      .toString()
      .trim()
      .slice(0, 140);

    // Step 1: Geospatial Proximity Check (15m radius)
    let matchedCluster = null;

    if (CLUSTERING_CATEGORIES.includes(category)) {
      const candidates = await Issue.find({
        category: category,
        status: { $in: ['Pending', 'In Progress'] },
        location: {
          $nearSphere: {
            $geometry: {
              type: 'Point',
              coordinates: [lng, lat]
            },
            $maxDistance: SEARCH_RADIUS_METERS
          }
        }
      });

      // Step 2: If candidates exist, evaluate Image Similarity via FastAPI
      if (candidates.length > 0) {
        try {
          // Map candidate image URLs to absolute local paths
          // Since URLs are like /uploads/photo-xxx.jpg, we resolve them relative to the server/uploads dir
          const aiPayload = {
            target_image_path: path.resolve(uploadedFile),
            candidates: candidates.map(c => ({
              issue_id: c._id.toString(),
              image_paths: c.imageUrls.map(img => {
                const filename = path.basename(img);
                return path.resolve(__dirname, '../uploads', filename);
              })
            })),
            min_inliers_threshold: 25
          };

          const { data: aiResult } = await axios.post(`${AI_SERVICE_URL}/api/v1/compare`, aiPayload);

          if (aiResult.is_duplicate && aiResult.matched_issue_id) {
            matchedCluster = await Issue.findById(aiResult.matched_issue_id);
          }
        } catch (aiErr) {
          console.error('AI Microservice failed. Falling back to standalone issue creation:', aiErr.message);
        }
      }
    }

    // Step 3A: Merge into Cluster
    if (matchedCluster) {
      matchedCluster.imageUrls.push(uploadedImageUrl);
      if (!matchedCluster.reporters.includes(userId)) {
        matchedCluster.reporters.push(userId);
      }
      matchedCluster.reportCount += 1;
      // Add status history entry for the merge/amplification
      matchedCluster.statusHistory.push({
        status: matchedCluster.status,
        changedBy: userId,
        changedAt: new Date(),
        note: `Merged duplicate report from user ${userId}. Report count amplified.`
      });
      await matchedCluster.save();

      return res.status(200).json({
        success: true,
        clustered: true,
        message: 'Your report matches an existing open issue and has been merged to amplify its priority.',
        issue: matchedCluster
      });
    }

    // Step 3B: Create Brand New Issue
    const createdAt = new Date();
    const newIssue = new Issue({
      userId, // for backwards-compatibility
      title: resolvedTitle,
      category,
      description: description || '',
      address: address || '',
      reporters: [userId],
      imageUrls: [uploadedImageUrl],
      reportCount: 1,
      location: {
        type: 'Point',
        coordinates: [lng, lat]
      },
      status: 'Pending',
      statusHistory: [
        {
          status: 'Pending',
          changedBy: userId,
          changedAt: createdAt,
          note: 'Complaint filed',
        },
      ],
      slaDeadline: sla.dueDate({ category, createdAt })
    });

    await newIssue.save();

    return res.status(201).json({
      success: true,
      clustered: false,
      message: 'New issue reported successfully.',
      issue: newIssue
    });

  } catch (error) {
    console.error('Error submitting issue:', error);
    res.status(500).json({ error: 'Server error processing the complaint.' });
  }
};
