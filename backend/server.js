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
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Send notification endpoint
app.post('/send-notification', async (req, res) => {
  try {
    const { fcmToken, placeName, lat, lng } = req.body;

    if (!fcmToken || !placeName) {
      return res.status(400).json({ error: 'fcmToken and placeName are required' });
    }

    const message = {
      notification: {
        title: 'Bus Arrival Alert',
        body: `Your bus is approaching ${placeName}!`
      },
      data: {
        placeName,
        lat: lat?.toString() || '',
        lng: lng?.toString() || ''
      },
      token: fcmToken
    };

    const response = await admin.messaging().send(message);
    console.log('Notification sent successfully:', response);
    
    res.json({ success: true, messageId: response });
  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ error: error.message });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`FCM v1 Backend running on port ${PORT}`);
});