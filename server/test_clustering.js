const mongoose = require('mongoose');
const path = require('path');
const dotenv = require('dotenv');
const axios = require('axios');
const fs = require('fs');
const FormData = require('form-data');

dotenv.config({ path: path.join(__dirname, '../.env') });

async function run() {
  console.log('Connecting to MongoDB at URI:', process.env.MONGO_URI);
  await mongoose.connect(process.env.MONGO_URI, { dbName: 'civic_connect' });
  
  const deleteResult = await mongoose.connection.db.collection('issues').deleteMany({
    title: { $regex: '^Pothole Test' }
  });
  console.log(`Cleaned up ${deleteResult.deletedCount} previous test complaints.`);
  await mongoose.disconnect();

  console.log('Logging in as citizen...');
  const loginRes = await axios.post('http://localhost:5000/api/auth/login', {
    email: 'citizen@civicconnect.org',
    password: 'password123'
  });
  const token = loginRes.data.token;
  console.log('Login successful. JWT token received.');

  const headers = {
    'Authorization': 'Bearer ' + token
  };

  const actualDir = 'C:/Users/varun/.gemini/antigravity-cli/brain/01fed43b-527e-4db3-9228-a7deb472f7f6/scratch/Pothole_Test_Small';

  const filenames = [
    '1(1).jpg', '1(2).jpg',
    '2(1).jpg', '2(2).jpg', '2(3).jpg',
    '3(1).jpg', '3(2).jpg',
    '4(1).jpg', '4(2).jpg', '4(3).jpg',
    '5(1).jpg', '5(2).jpg', '5(3).jpg', '5(4).jpg', '5(5).jpg',
    '6(1).jpg', '6(2).jpg', '6(3).jpg',
    '7(1).jpg', '7(2).jpg', '7(3).jpg'
  ];

  console.log('\n--- Starting Clustering Test Loop ---\n');
  const results = [];

  for (const filename of filenames) {
    console.log(`Processing file: ${filename}...`);
    const filePath = path.join(actualDir, filename);

    // Upload image
    const form = new FormData();
    form.append('photo', fs.createReadStream(filePath));
    const uploadRes = await axios.post('http://localhost:5000/api/issues/upload', form, {
      headers: {
        ...headers,
        ...form.getHeaders()
      }
    });

    const fileUrl = uploadRes.data.url;
    console.log(`  Uploaded successfully. URL: ${fileUrl}`);

    // Create complaint
    const complaintData = {
      title: 'Pothole Test ' + filename.split('(')[0],
      category: 'pothole',
      description: 'Test report for pothole ' + filename,
      imageUrl: fileUrl,
      imageUrls: [fileUrl],
      latitude: 19.046211,
      longitude: 72.871308,
      address: 'Pothole Test Street, Sector 12, Bandra West'
    };

    const createRes = await axios.post('http://localhost:5000/api/issues', complaintData, { headers });
    const issue = createRes.data.issue;
    const clustered = createRes.data.clustered;

    if (clustered) {
      console.log(`  Result for ${filename}:`);
      console.log(`    [MERGED] Placed into existing issue ID: ${issue._id}`);
      console.log(`    [STATS] Report count: ${issue.reportCount} | Total images in cluster: ${issue.imageUrls.length}\n`);
    } else {
      console.log(`  Result for ${filename}:`);
      console.log(`    [CREATED] New issue created with ID: ${issue._id}`);
      console.log(`    [STATS] Report count: ${issue.reportCount} | Total images in cluster: ${issue.imageUrls.length}\n`);
    }

    results.push({
      filename,
      isClustered: clustered,
      issueId: issue._id,
      reportCount: issue.reportCount,
      imagesCount: issue.imageUrls.length
    });
  }

  console.log('\n--- Summary Table ---');
  console.table(results);
}

run().catch(console.error);
