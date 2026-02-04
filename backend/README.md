# FCM v1 Node.js Backend

Minimal Node.js backend for sending FCM v1 push notifications.

## Setup

1. **Install dependencies:**
```bash
npm install
```

2. **Set environment variables:**
```bash
cp .env.example .env
# Edit .env and add your Firebase service account JSON
```

3. **Run locally:**
```bash
npm run dev  # Development with nodemon
npm start    # Production
```

## API Endpoints

### POST /send-notification
Send FCM v1 push notification to a device.

**Request:**
```json
{
  "fcmToken": "device_fcm_token",
  "placeName": "Bus Stop Name",
  "lat": 12.345,
  "lng": 67.890
}
```

**Response:**
```json
{
  "success": true,
  "messageId": "projects/your-project/messages/0:1234567890"
}
```

### GET /health
Health check endpoint.

## Deployment

### Render.com
1. Connect GitHub repository
2. Set environment variable: `FIREBASE_SERVICE_ACCOUNT`
3. Deploy

### Railway/Heroku
1. Connect repository
2. Set `FIREBASE_SERVICE_ACCOUNT` environment variable
3. Deploy

### Hostinger VPS
```bash
# Upload files
npm install
export FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
npm start
```

## Environment Variables

- `FIREBASE_SERVICE_ACCOUNT`: Firebase service account JSON (required)
- `PORT`: Server port (optional, defaults to 3000)