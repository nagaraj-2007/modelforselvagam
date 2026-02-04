const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin SDK
try {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log('✅ Firebase Admin SDK initialized successfully');
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin SDK:', error);
  process.exit(1);
}

// Initialize Firestore
const db = admin.firestore();

// Home endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Bus Tracking Backend API (Node.js)',
    endpoints: {
      'POST /check-location': 'Send bus arrival notification',
      'GET /get-arrivals': 'Get arrival history',
      'GET /health': 'Health check'
    },
    version: '1.0.0'
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'Bus Tracking Backend (Node.js)'
  });
});

// Check location and send notification
app.post('/check-location', async (req, res) => {
  try {
    const { lat, lng, fcmToken, placeName } = req.body;

    // Validate required fields
    const requiredFields = ['lat', 'lng', 'fcmToken', 'placeName'];
    for (const field of requiredFields) {
      if (!req.body[field]) {
        return res.status(400).json({ success: false, error: `${field} is required` });
      }
    }

    if (typeof lat !== 'number' || typeof lng !== 'number') {
      return res.status(400).json({ success: false, error: 'lat and lng must be numbers' });
    }

    console.log(`📍 Location check: ${placeName} at (${lat}, ${lng})`);

    // Store in Firestore
    const tripData = {
      placeName,
      latitude: lat,
      longitude: lng,
      fcmToken,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: 'arrived'
    };

    const docRef = await db.collection('bus_arrivals').add(tripData);
    console.log(`💾 Stored in Firestore: ${docRef.id}`);

    // Send FCM notification
    const message = {
      notification: {
        title: '🚌 Bus Arrived!',
        body: `Your bus has reached ${placeName}. Please get ready!`
      },
      data: {
        location_name: placeName,
        latitude: lat.toString(),
        longitude: lng.toString(),
        timestamp: new Date().toISOString(),
        firestore_id: docRef.id
      },
      android: {
        priority: 'high',
        notification: {
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true
        }
      },
      token: fcmToken
    };

    const response = await admin.messaging().send(message);
    console.log(`✅ FCM notification sent: ${response}`);

    res.json({
      success: true,
      message: 'Notification sent successfully',
      fcmResponse: response,
      firestoreId: docRef.id,
      location: { placeName, coordinates: { lat, lng } }
    });

  } catch (error) {
    console.error(`❌ Error: ${error}`);
    res.status(500).json({ success: false, error: 'Failed to send notification', details: error.message });
  }
});

// Get arrivals history
app.get('/get-arrivals', async (req, res) => {
  try {
    const snapshot = await db.collection('bus_arrivals')
      .orderBy('timestamp', 'desc')
      .limit(50)
      .get();

    const arrivals = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      arrivals.push({
        id: doc.id,
        ...data,
        timestamp: data.timestamp ? data.timestamp.toDate().toISOString() : null
      });
    });

    res.json({
      success: true,
      arrivals,
      count: arrivals.length
    });

  } catch (error) {
    console.error(`❌ Error fetching arrivals: ${error}`);
    res.status(500).json({ success: false, error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 Bus Tracking Backend running on port ${PORT}`);
});