# Backend Deployment Guide

## Quick Setup

### 1. Get Firebase Service Account Key
1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Download the JSON file
4. Copy the entire JSON content

### 2. Deploy to Render.com (Recommended)

1. **Fork/Upload to GitHub**
   - Upload the `backend/` folder to a GitHub repository

2. **Create Render Service**
   - Go to render.com → New → Web Service
   - Connect your GitHub repository
   - Select the `backend` folder

3. **Configure Settings**
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `python app.py`
   - **Environment Variables**:
     ```
     FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"your-project-id",...}
     PORT=3000
     ```

4. **Deploy**
   - Click "Create Web Service"
   - Get your URL: `https://your-app-name.onrender.com`

### 3. Update Flutter App

In `module2_sender/lib/main.dart`, update:
```dart
const String BACKEND_URL = 'https://your-app-name.onrender.com';
```

## Alternative Deployments

### Hostinger VPS
```bash
# SSH into your VPS
ssh user@your-server.com

# Upload files
scp -r backend/ user@your-server.com:~/

# Install dependencies
cd backend
pip3 install -r requirements.txt

# Set environment variable
export FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'

# Run (use screen/tmux for persistence)
python3 app.py
```

### Railway.app
1. Connect GitHub repository
2. Set environment variable: `FIREBASE_SERVICE_ACCOUNT`
3. Deploy automatically

### Local Testing
```bash
cd backend
pip install -r requirements.txt
export FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
python app.py
```

## Testing Your Backend

### 1. Health Check
```bash
curl https://your-backend-url.com/health
```

### 2. Test Notification
```bash
curl -X POST https://your-backend-url.com/check-location \
  -H "Content-Type: application/json" \
  -d '{
    "lat": 40.7128,
    "lng": -74.0060,
    "fcmToken": "your-fcm-token",
    "placeName": "Test Location"
  }'
```

## Troubleshooting

### Common Issues
1. **Firebase Admin SDK Error**: Check service account JSON format
2. **CORS Error**: Backend should handle CORS automatically
3. **FCM Token Invalid**: Get fresh token from passenger app
4. **Port Issues**: Render uses PORT environment variable

### Logs
- **Render**: Check logs in dashboard
- **Local**: Console output shows requests and errors