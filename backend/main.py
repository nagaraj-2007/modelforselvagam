from flask import Flask, request, jsonify
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, messaging
import os
import json
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Initialize Firebase Admin SDK
try:
    service_account_info = json.loads(os.environ.get('FIREBASE_SERVICE_ACCOUNT', '{}'))
    cred = credentials.Certificate(service_account_info)
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin SDK initialized successfully")
except Exception as e:
    print(f"❌ Failed to initialize Firebase Admin SDK: {e}")
    exit(1)

@app.route('/', methods=['GET'])
def home():
    return jsonify({
        'message': 'Bus Tracking Backend API (Python)',
        'endpoints': {
            'POST /check-location': 'Send bus arrival notification',
            'GET /health': 'Health check'
        },
        'version': '1.0.0'
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': str(datetime.utcnow()),
        'service': 'Bus Tracking Backend (Python)'
    })

@app.route('/check-location', methods=['POST'])
def check_location():
    try:
        data = request.get_json()
        
        required_fields = ['lat', 'lng', 'fcmToken', 'placeName']
        for field in required_fields:
            if field not in data:
                return jsonify({'success': False, 'error': f'{field} is required'}), 400
        
        lat, lng, fcm_token, place_name = data['lat'], data['lng'], data['fcmToken'], data['placeName']
        
        if not isinstance(lat, (int, float)) or not isinstance(lng, (int, float)):
            return jsonify({'success': False, 'error': 'lat and lng must be numbers'}), 400
        
        print(f"📍 Location check: {place_name} at ({lat}, {lng})")
        
        message = messaging.Message(
            notification=messaging.Notification(
                title='🚌 Bus Arrived!',
                body=f'Your bus has reached {place_name}. Please get ready!'
            ),
            data={
                'location_name': place_name,
                'latitude': str(lat),
                'longitude': str(lng),
                'timestamp': str(datetime.utcnow())
            },
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    priority='high',
                    default_sound=True,
                    default_vibrate_timings=True
                )
            ),
            token=fcm_token
        )
        
        response = messaging.send(message)
        print(f"✅ FCM notification sent: {response}")
        
        return jsonify({
            'success': True,
            'message': 'Notification sent successfully',
            'fcmResponse': response,
            'location': {'placeName': place_name, 'coordinates': {'lat': lat, 'lng': lng}}
        })
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return jsonify({'success': False, 'error': 'Failed to send notification', 'details': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 3000))
    print(f"🚀 Bus Tracking Backend running on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)