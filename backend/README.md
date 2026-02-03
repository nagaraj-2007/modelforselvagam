# Bus Tracking Backend

Node.js backend for bus tracking system with FCM push notifications.

## Features

- ✅ Express.js REST API
- ✅ Firebase Admin SDK for FCM notifications
- ✅ CORS support
- ✅ Request validation
- ✅ Error handling
- ✅ Render deployment ready

## API Endpoints

### POST /check-location
Send bus arrival notification to passenger.

**Request Body:**
```json
{
  "lat": 10.081642,
  "lng": 78.746657,
  "fcmToken": "passenger_fcm_token_here",
  "placeName": "School Gate"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Notification sent successfully",
  "fcmResponse": "firebase_message_id",
  "location": {
    "placeName": "School Gate",
    "coordinates": { "lat": 10.081642, "lng": 78.746657 }
  }
}
```

### GET /health
Health check endpoint.

### GET /
API information and available endpoints.

## Local Development

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Set environment variable:**
   ```bash
   export FIREBASE_SERVICE_ACCOUNT='{"type":"service_account","project_id":"your-project",...}'
   ```

3. **Run server:**
   ```bash
   npm start
   # or for development with auto-reload:
   npm run dev
   ```

## Render Deployment

1. **Create new Web Service on Render**
2. **Connect your GitHub repository**
3. **Set build command:** `npm install`
4. **Set start command:** `npm start`
5. **Add environment variable:**
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Value: Your complete Firebase service account JSON (as string)

## Environment Variables

- `FIREBASE_SERVICE_ACCOUNT` - Firebase service account JSON (required)
- `PORT` - Server port (default: 3000)

## Firebase Service Account Setup

1. Go to Firebase Console > Project Settings > Service Accounts
2. Click "Generate new private key"
3. Copy the entire JSON content
4. Set as `FIREBASE_SERVICE_ACCOUNT` environment variable in Render

## Usage with Flutter App

```dart
final response = await http.post(
  Uri.parse('https://your-render-app.onrender.com/check-location'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'lat': 10.081642,
    'lng': 78.746657,
    'fcmToken': passengerFcmToken,
    'placeName': 'School Gate'
  }),
);
```