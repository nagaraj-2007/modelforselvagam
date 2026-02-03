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
    # For production, use environment variable
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
        
        # Validate required fields
        required_fields = ['lat', 'lng', 'fcmToken', 'placeName']
        for field in required_fields:
            if field not in data:
                return jsonify({
                    'success': False,
                    'error': f'{field} is required'
                }), 400
        
        lat = data['lat']
        lng = data['lng']
        fcm_token = data['fcmToken']
        place_name = data['placeName']
        
        # Validate data types
        if not isinstance(lat, (int, float)) or not isinstance(lng, (int, float)):
            return jsonify({
                'success': False,
                'error': 'lat and lng must be numbers'
            }), 400
        
        if not isinstance(fcm_token, str) or not isinstance(place_name, str):
            return jsonify({
                'success': False,
                'error': 'fcmToken and placeName must be strings'
            }), 400
        
        print(f"📍 Location check: {place_name} at ({lat}, {lng})")
        
        # Create FCM message
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
        
        # Send FCM notification
        response = messaging.send(message)
        
        print(f"✅ FCM notification sent successfully: {response}")
        
        return jsonify({
            'success': True,
            'message': 'Notification sent successfully',
            'fcmResponse': response,
            'location': {
                'placeName': place_name,
                'coordinates': {'lat': lat, 'lng': lng}
            }
        })
        
    except Exception as e:
        print(f"❌ Error sending notification: {e}")
        return jsonify({
            'success': False,
            'error': 'Failed to send notification',
            'details': str(e)
        }), 500

@app.errorhandler(404)
def not_found(error):
    return jsonify({
        'success': False,
        'error': 'Endpoint not found'
    }), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({
        'success': False,
        'error': 'Internal server error'
    }), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 3000))
    print(f"🚀 Bus Tracking Backend (Python) running on port {port}")
    print(f"📡 Health check: http://localhost:{port}/health")
    app.run(host='0.0.0.0', port=port, debug=False)