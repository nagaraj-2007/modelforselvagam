import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';

const String BACKEND_URL = 'https://your-backend-url.com'; // Replace with your backend URL

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeService();
  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      autoStartOnBoot: false,
    ),
  );
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  final prefs = await SharedPreferences.getInstance();
  String? fcmToken = prefs.getString('passengerFcmToken');
  String? placeName = prefs.getString('targetPlaceName');
  double? targetLat = prefs.getDouble('targetLat');
  double? targetLng = prefs.getDouble('targetLng');
  
  if (fcmToken == null || placeName == null || targetLat == null || targetLng == null) {
    service.stopSelf();
    return;
  }

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLat,
        targetLng,
      );
      
      service.invoke('update', {
        'distance': distance.round(),
        'lat': position.latitude,
        'lng': position.longitude,
      });
      
      if (distance <= 100) {
        await _sendNotificationToBackend(
          position.latitude,
          position.longitude,
          fcmToken,
          placeName,
        );
        
        timer.cancel();
        service.stopSelf();
      }
    } catch (e) {
      print('Background service error: $e');
    }
  });
}

Future<void> _sendNotificationToBackend(double lat, double lng, String fcmToken, String placeName) async {
  try {
    final response = await http.post(
      Uri.parse('$BACKEND_URL/check-location'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'lat': lat,
        'lng': lng,
        'fcmToken': fcmToken,
        'placeName': placeName,
      }),
    );
    
    if (response.statusCode == 200) {
      print('Notification sent successfully');
    } else {
      print('Failed to send notification: ${response.statusCode}');
    }
  } catch (e) {
    print('Error sending notification: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bus Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const BusTrackerScreen(),
    );
  }
}

class BusTrackerScreen extends StatefulWidget {
  const BusTrackerScreen({super.key});

  @override
  State<BusTrackerScreen> createState() => _BusTrackerScreenState();
}

class _BusTrackerScreenState extends State<BusTrackerScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isTracking = false;
  String? _passengerFcmToken;
  String? _targetPlaceName;
  LatLng? _targetLocation;
  double? _currentDistance;
  Set<Marker> _markers = {};
  
  final TextEditingController _fcmTokenController = TextEditingController();
  final TextEditingController _placeNameController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadSavedData();
    _setupServiceListener();
  }

  void _setupServiceListener() {
    final service = FlutterBackgroundService();
    service.on('update').listen((event) {
      if (mounted) {
        setState(() {
          _currentDistance = event?['distance']?.toDouble();
        });
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) return;
    
    Position position = await Geolocator.getCurrentPosition();
    setState(() => _currentPosition = position);
    
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        15,
      ),
    );
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _passengerFcmToken = prefs.getString('passengerFcmToken');
      _targetPlaceName = prefs.getString('targetPlaceName');
      double? lat = prefs.getDouble('targetLat');
      double? lng = prefs.getDouble('targetLng');
      if (lat != null && lng != null) {
        _targetLocation = LatLng(lat, lng);
        _updateMarkers();
      }
    });
    
    if (_passengerFcmToken != null) {
      _fcmTokenController.text = _passengerFcmToken!;
    }
    if (_targetPlaceName != null) {
      _placeNameController.text = _targetPlaceName!;
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('passengerFcmToken', _fcmTokenController.text);
    await prefs.setString('targetPlaceName', _placeNameController.text);
    if (_targetLocation != null) {
      await prefs.setDouble('targetLat', _targetLocation!.latitude);
      await prefs.setDouble('targetLng', _targetLocation!.longitude);
    }
  }

  void _setTarget() {
    if (_fcmTokenController.text.isEmpty || _placeNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter FCM token and place name')),
      );
      return;
    }
    
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Getting location...')),
      );
      return;
    }
    
    setState(() {
      _passengerFcmToken = _fcmTokenController.text;
      _targetPlaceName = _placeNameController.text;
      _targetLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      _updateMarkers();
    });
    
    _saveData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Target set at ${_placeNameController.text}')),
    );
  }

  void _onMapTap(LatLng position) {
    if (_fcmTokenController.text.isEmpty || _placeNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter FCM token and place name first')),
      );
      return;
    }

    setState(() {
      _passengerFcmToken = _fcmTokenController.text;
      _targetPlaceName = _placeNameController.text;
      _targetLocation = position;
      _updateMarkers();
    });
    
    _saveData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Target set at ${_placeNameController.text}')),
    );
  }

  void _updateMarkers() {
    _markers.clear();
    if (_targetLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('target'),
          position: _targetLocation!,
          infoWindow: InfoWindow(title: _targetPlaceName ?? 'Target'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  void _removeTarget() {
    setState(() {
      _targetLocation = null;
      _targetPlaceName = null;
      _currentDistance = null;
      _markers.clear();
    });
    
    _clearSavedTarget();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Target removed')),
    );
  }

  Future<void> _clearSavedTarget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('targetPlaceName');
    await prefs.remove('targetLat');
    await prefs.remove('targetLng');
  }

  Future<void> _toggleTracking() async {
    if (_passengerFcmToken == null || _targetLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set target first')),
      );
      return;
    }

    final service = FlutterBackgroundService();
    
    if (_isTracking) {
      service.invoke('stopService');
      setState(() => _isTracking = false);
    } else {
      await Permission.locationAlways.request();
      await service.startService();
      setState(() => _isTracking = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Tracker'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Map
          SizedBox(
            height: 250,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null
                    ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                    : const LatLng(0, 0),
                zoom: 15,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: _onMapTap,
              myLocationEnabled: true,
              markers: _markers,
            ),
          ),
          
          // Controls
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _fcmTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Passenger FCM Token',
                      border: OutlineInputBorder(),
                      hintText: 'Paste FCM token from passenger app',
                    ),
                    maxLines: 2,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _placeNameController,
                    decoration: const InputDecoration(
                      labelText: 'Place Name',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., School Gate, Bus Stop A',
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _setTarget,
                          icon: const Icon(Icons.my_location),
                          label: const Text('Set Target Here'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_targetLocation != null)
                        ElevatedButton.icon(
                          onPressed: _removeTarget,
                          icon: const Icon(Icons.clear),
                          label: const Text('Remove'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  if (_targetLocation != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target: $_targetPlaceName',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (_currentDistance != null)
                              Text('Distance: ${_currentDistance!.toStringAsFixed(0)}m'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _toggleTracking,
                      icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                      label: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTracking ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  const Card(
                    color: Colors.blue,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Icon(Icons.info, color: Colors.white),
                          SizedBox(height: 8),
                          Text(
                            'How to use:',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '1. Get FCM token from passenger app\n2. Enter place name\n3. Tap map or use "Set Target Here"\n4. Start tracking\n\nTip: Tap anywhere on map to set target',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}