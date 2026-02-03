const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin SDK
try {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('✅ Firebase Admin SDK initialized successfully');
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
  process.exit(1);
}

// Validation middleware
const validateLocationRequest = (req, res, next) => {
  const { lat, lng, fcmToken, placeName } = req.body;
  
  if (typeof lat !== 'number' || typeof lng !== 'number') {
    return res.status(400).json({
      success: false,
      error: 'lat and lng must be numbers'
    });
  }
  
  if (!fcmToken || typeof fcmToken !== 'string') {
    return res.status(400).json({
      success: false,
      error: 'fcmToken is required and must be a string'
    });
  }
  
  if (!placeName || typeof placeName !== 'string') {
    return res.status(400).json({
      success: false,
      error: 'placeName is required and must be a string'
    });
  }
  
  next();
};

// Main endpoint
app.post('/check-location', validateLocationRequest, async (req, res) => {
  try {
    const { lat, lng, fcmToken, placeName } = req.body;
    
    console.log(`📍 Location check: ${placeName} at (${lat}, ${lng})`);
    
    // Prepare FCM message
    const message = {
      token: fcmToken,
      notification: {
        title: '🚌 Bus Arrived!',
        body: `Your bus has reached ${placeName}. Please get ready!`
      },
      android: {
        priority: 'high',
        notification: {
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true
        }
      },
      data: {
        location_name: placeName,
        latitude: lat.toString(),
        longitude: lng.toString(),
        timestamp: new Date().toISOString()
      }
    };
    
    // Send FCM notification
    const response = await admin.messaging().send(message);
    
    console.log('✅ FCM notification sent successfully:', response);
    
    res.json({
      success: true,
      message: 'Notification sent successfully',
      fcmResponse: response,
      location: {
        placeName,
        coordinates: { lat, lng }
      }
    });
    
  } catch (error) {
    console.error('❌ Error sending notification:', error);
    
    res.status(500).json({
      success: false,
      error: 'Failed to send notification',
      details: error.message
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'Bus Tracking Backend'
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Bus Tracking Backend API',
    endpoints: {
      'POST /check-location': 'Send bus arrival notification',
      'GET /health': 'Health check'
    },
    version: '1.0.0'
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('❌ Unhandled error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Bus Tracking Backend running on port ${PORT}`);
  console.log(`📡 Health check: http://localhost:${PORT}/health`);
});

module.exports = app;