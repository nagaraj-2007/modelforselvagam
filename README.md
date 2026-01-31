
FCM V1 Flutter Two-Module Setup (Firestore Version)
==============================

This project uses **Firestore only** (no Firebase Cloud Functions or FCM) on the **Spark (free) plan**.

## Architecture

**module2_sender (Bus App):**
- Tracks GPS location in background
- Creates targets in Firestore
- Updates Firestore when within 100m of target
- Sets `reached: true` and `reachedAt: timestamp`

**module1_receiver (Passenger App):**
- Listens to Firestore document in real-time
- Shows local notification when `reached` becomes `true`
- No server-side push notifications needed

## Firestore Structure

```
Collection: targets
Document fields:
  - name (string): Target location name
  - location (GeoPoint): Target coordinates
  - radius (number): Detection radius in meters (default: 100)
  - reached (boolean): Whether bus has reached target
  - reachedAt (timestamp): When target was reached
```

## Setup Instructions

1. **Create Firebase Project:**
   - Go to Firebase Console
   - Create new project
   - Enable Firestore (Spark/free plan)
   - Add Android/iOS apps

2. **Configure Firebase:**
   - Download `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)
   - Update `firebase_options.dart` in both modules with your project details
   - Deploy the `firestore.rules` file

3. **Install Dependencies:**
   ```bash
   cd module1_receiver && flutter pub get
   cd ../module2_sender && flutter pub get
   ```

## Usage

1. **Bus Driver (module2_sender):**
   - Enter target name
   - Tap "Create Target at Current Location"
   - Share the Target ID with passengers
   - Tap "Start Tracking"
   - App will update Firestore when within 100m

2. **Passenger (module1_receiver):**
   - Enter Target ID from bus driver
   - Tap "Start Listening"
   - Receive notification when bus arrives

## Features

- ✅ Background location tracking
- ✅ Real-time Firestore updates
- ✅ Local notifications
- ✅ No server-side code needed
- ✅ Free Firebase Spark plan compatible
- ✅ Simple security rules for testing

## Testing

- Create a target at current location
- Move 100+ meters away
- Start tracking
- Walk back to target location
- Notification should trigger automatically
