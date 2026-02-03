FCM V1 Flutter Two-Module Setup (Push Notification Version)
==============================

This project uses **FCM v1 push notifications** with a **Python/Node.js backend** for real-time bus arrival notifications.

## Architecture

**module2_sender (Bus App):**
- Tracks GPS location in background
- Sends HTTP requests to backend when within 100m of target
- Backend uses Firebase Admin SDK to send FCM v1 notifications

**module1_receiver (Passenger App):**
- Receives FCM push notifications
- Shows local notification + voice announcement
- No polling needed - instant delivery

**Backend (Python/Node.js):**
- Receives location data from bus app
- Uses Firebase Admin SDK to send FCM v1 notifications
- Deployable on Hostinger, Render, or any cloud platform

## Data Flow

```
module2_sender (Flutter)
   ↓ HTTP (lat, lng, fcmToken, placeName)
Python/Node.js Backend (Hostinger/Render)
   ↓ Firebase Admin SDK (FCM v1)
module1_receiver (Flutter)
   ↓ Push Notification + TTS
```

## Setup Instructions

### 1. Firebase Setup
- Create Firebase project
- Enable FCM (Cloud Messaging)
- Download service account key JSON
- Add Android/iOS apps and download config files

### 2. Backend Deployment

#### Option A: Python Backend (Flask)
```bash
cd backend
pip install -r requirements.txt
export FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
python app.py
```

#### Option B: Node.js Backend (Express)
```bash
cd backend
npm install
export FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
npm start
```

### 3. Flutter Apps Setup
```bash
# Install dependencies
cd module1_receiver && flutter pub get
cd ../module2_sender && flutter pub get

# Update backend URL in module2_sender/lib/main.dart
const String BACKEND_URL = 'https://your-backend-url.com';
```

## Usage

### 1. Passenger (module1_receiver):
- Open app to get FCM token
- Share FCM token with bus driver
- Receive push notifications when bus arrives

### 2. Bus Driver (module2_sender):
- Enter passenger's FCM token
- Enter destination name
- Set target at current location
- Start tracking
- Notification sent automatically when within 100m

## Features

- ✅ Real FCM v1 push notifications
- ✅ Background location tracking
- ✅ Voice announcements (TTS)
- ✅ Local notifications
- ✅ Scalable backend architecture
- ✅ No Firebase Spark plan limitations
- ✅ Instant delivery
- ✅ Battery efficient

## Backend Deployment Options

### Hostinger VPS
```bash
# Upload files via FTP/SSH
pip install -r requirements.txt
export FIREBASE_SERVICE_ACCOUNT='...'
python app.py
```

### Render.com
- Connect GitHub repository
- Set environment variable: `FIREBASE_SERVICE_ACCOUNT`
- Auto-deploy on push

### Railway/Heroku
- Similar to Render
- Set environment variables
- Deploy from Git

## Environment Variables

```bash
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"..."}
PORT=3000
```

## Testing

1. Deploy backend and get URL
2. Update `BACKEND_URL` in module2_sender
3. Get FCM token from passenger app
4. Enter token in bus app
5. Set target and start tracking
6. Move 100+ meters away and walk back
7. Notification should arrive instantly

## Advantages over Firestore Version

- **Instant delivery**: Push notifications vs polling
- **Better battery life**: No continuous Firestore listening
- **Scalable**: Backend can handle multiple buses/passengers
- **Reliable**: FCM handles delivery even when app is closed
- **Cost effective**: No Firestore read/write costs