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

// Initialize Firestore
const db = admin.firestore();

// Send notification endpoint
app.post('/send-notification', async (req, res) => {
  try {
    const { fcmToken, placeName, lat, lng } = req.body;

    if (!fcmToken || !placeName) {
      return res.status(400).json({ error: 'fcmToken and placeName are required' });
    }

    // Save to Firestore
    const notificationData = {
      fcmToken,
      placeName,
      lat: lat || null,
      lng: lng || null,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: 'sent'
    };

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
    notificationData.messageId = response;
    
    // Store in Firestore
    await db.collection('notifications').add(notificationData);
    
    console.log('Notification sent and saved:', response);
    res.json({ success: true, messageId: response });
  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get notifications history
app.get('/notifications', async (req, res) => {
  try {
    const snapshot = await db.collection('notifications')
      .orderBy('timestamp', 'desc')
      .limit(50)
      .get();
    
    const notifications = [];
    snapshot.forEach(doc => {
      notifications.push({ id: doc.id, ...doc.data() });
    });
    
    res.json(notifications);
  } catch (error) {
    console.error('Error fetching notifications:', error);
    res.status(500).json({ error: error.message });
  }
});

// Register passenger
app.post('/register-passenger', async (req, res) => {
  try {
    const { fcmToken, name, phone } = req.body;
    
    if (!fcmToken) {
      return res.status(400).json({ error: 'fcmToken is required' });
    }
    
    const passengerData = {
      fcmToken,
      name: name || 'Anonymous',
      phone: phone || null,
      registeredAt: admin.firestore.FieldValue.serverTimestamp(),
      active: true
    };
    
    const docRef = await db.collection('passengers').add(passengerData);
    res.json({ success: true, passengerId: docRef.id });
  } catch (error) {
    console.error('Error registering passenger:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get passengers
app.get('/passengers', async (req, res) => {
  try {
    const snapshot = await db.collection('passengers')
      .where('active', '==', true)
      .orderBy('registeredAt', 'desc')
      .get();
    
    const passengers = [];
    snapshot.forEach(doc => {
      passengers.push({ id: doc.id, ...doc.data() });
    });
    
    res.json(passengers);
  } catch (error) {
    console.error('Error fetching passengers:', error);
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