
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundService.initialize();
  runApp(const MyApp());
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          primary: const Color(0xFF1A237E),
          secondary: const Color(0xFF00C853),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isBackgroundTracking = false;
  Timer? _statusTimer;
  
  final TextEditingController _tokenController = TextEditingController();
  
  Map<String, dynamic>? _startLocation;
  Map<String, dynamic>? _targetLocation;

  @override
  void initState() {
    super.initState();
    _stopAnyExistingService(); // Stop any service from previous session
    _loadStoredData();
    _startStatusPoller();
    _getCurrentLocation();
  }

  Future<void> _stopAnyExistingService() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke("stopService");
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusPoller() {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if target was reached
      final targetReached = prefs.getBool('targetReached') ?? false;
      if (targetReached && _targetLocation != null) {
        setState(() {
          _targetLocation!['reached'] = true;
        });
      }
      
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (mounted) {
        setState(() {
          _isBackgroundTracking = isRunning;
        });
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = pos);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15));
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.location.request();
    if (status.isPermanentlyDenied) {
      openAppSettings();
      return;
    }

    if (await Permission.location.isGranted) {
      var bgStatus = await Permission.locationAlways.request();
      if (bgStatus.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Background location is required. Please select "Allow all the time" in settings.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    }
    
    await Permission.notification.request();
  }

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('fcmToken');
    if (storedToken != null && storedToken.isNotEmpty) {
       _tokenController.text = storedToken;
    }
    
    final startLocJson = prefs.getString('startLocation');
    if (startLocJson != null) {
      setState(() {
        _startLocation = Map<String, dynamic>.from(jsonDecode(startLocJson));
      });
    }
    
    final targetLocJson = prefs.getString('targetLocation');
    if (targetLocJson != null) {
      setState(() {
        _targetLocation = Map<String, dynamic>.from(jsonDecode(targetLocJson));
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcmToken', _tokenController.text.trim());
    
    if (_startLocation != null) {
      await prefs.setString('startLocation', jsonEncode(_startLocation));
    }
    
    if (_targetLocation != null) {
      await prefs.setString('targetLocation', jsonEncode(_targetLocation));
      await prefs.setBool('targetReached', _targetLocation!['reached'] ?? false);
    }
    
    try {
      final serviceAccountJson = await rootBundle.loadString('assets/service-account-key.json');
      await prefs.setString('serviceAccountJson', serviceAccountJson);
    } catch (e) {
      print("Error loading service account: $e");
    }
  }

  Future<void> _setStartLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      
      setState(() {
        _startLocation = {
          'name': 'Start Location',
          'lat': position.latitude,
          'lng': position.longitude,
        };
        _currentPosition = position;
      });
      
      await _saveData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Start Location Saved: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          16,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _setTargetLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      
      setState(() {
        _targetLocation = {
          'name': 'Target Location',
          'lat': position.latitude,
          'lng': position.longitude,
          'reached': false,
        };
        _currentPosition = position;
      });
      
      await _saveData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Target Location Saved: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          16,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleTracking() async {
    if (_isBackgroundTracking) {
      final service = FlutterBackgroundService();
      service.invoke("stopService");
      setState(() => _isBackgroundTracking = false);
    } else {
      if (_tokenController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter Receiver Token first')),
        );
        return;
      }

      if (_targetLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set Target Location first')),
        );
        return;
      }

      await _requestPermissions();
      await _saveData();
      
      final service = FlutterBackgroundService();
      await service.startService();
      setState(() => _isBackgroundTracking = true);
      
      // If already at target location, trigger immediately
      if (_currentPosition != null && _targetLocation != null) {
        double distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          _targetLocation!['lat'],
          _targetLocation!['lng'],
        );
        
        if (distance <= 150) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Already at target! Distance: ${distance.toStringAsFixed(0)}m - Notification will be sent automatically')),
          );
        }
      }
    }
  }

  Future<void> _sendTestNotification() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token required')));
      return;
    }

    try {
      final serviceAccountJson = await rootBundle.loadString('assets/service-account-key.json');
      final serviceAccount = jsonDecode(serviceAccountJson);
      
      final credentials = ServiceAccountCredentials.fromJson(serviceAccount);
      final client = await clientViaServiceAccount(
        credentials,
        ['https://www.googleapis.com/auth/firebase.messaging'],
      );

      final response = await client.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/${serviceAccount['project_id']}/messages:send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {
              'title': 'Test: Bus Reached Your Destination!',
              'body': 'Manual test notification - checking connection',
            },
            'android': {'priority': 'high'},
          },
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test notification sent successfully!')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${response.statusCode}')));
      }
      client.close();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _resetLocations() {
    setState(() {
      _startLocation = null;
      _targetLocation = null;
    });
    _saveData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Locations cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {};
    
    if (_startLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: LatLng(_startLocation!['lat'], _startLocation!['lng']),
        infoWindow: const InfoWindow(title: 'Start Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    
    if (_targetLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('target'),
        position: LatLng(_targetLocation!['lat'], _targetLocation!['lng']),
        infoWindow: const InfoWindow(title: 'Target Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _targetLocation!['reached'] == true ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRed,
        ),
      ));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Bus Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetLocations,
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: Column(
        children: [
          // Map Section
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null 
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(10.081642, 78.746657),
                zoom: 15,
              ),
              onMapCreated: (c) => _mapController = c,
              markers: markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
          
          // Controls Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Receiver Token', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _tokenController,
                            decoration: const InputDecoration(
                              labelText: 'FCM Token',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.key),
                            ),
                            style: const TextStyle(fontSize: 12),
                            onChanged: (v) => _saveData(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Location Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _setStartLocation,
                          icon: const Icon(Icons.play_circle),
                          label: const Text('Set Start'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _setTargetLocation,
                          icon: const Icon(Icons.location_on),
                          label: const Text('Set Target'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Status Cards
                  if (_startLocation != null)
                    Card(
                      color: Colors.green[50],
                      child: ListTile(
                        leading: const Icon(Icons.play_circle, color: Colors.green),
                        title: const Text('Start Location', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Lat: ${_startLocation!['lat'].toStringAsFixed(6)}\nLng: ${_startLocation!['lng'].toStringAsFixed(6)}'),
                      ),
                    ),
                  
                  if (_targetLocation != null)
                    Card(
                      color: _targetLocation!['reached'] == true ? Colors.orange[50] : Colors.red[50],
                      child: ListTile(
                        leading: Icon(
                          _targetLocation!['reached'] == true ? Icons.check_circle : Icons.location_on,
                          color: _targetLocation!['reached'] == true ? Colors.orange : Colors.red,
                        ),
                        title: const Text('Target Location', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Lat: ${_targetLocation!['lat'].toStringAsFixed(6)}\nLng: ${_targetLocation!['lng'].toStringAsFixed(6)}'),
                        trailing: _currentPosition != null && _targetLocation!['reached'] != true
                          ? Text(
                              '${Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, _targetLocation!['lat'], _targetLocation!['lng']).toStringAsFixed(0)}m',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )
                          : null,
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Start/Stop Tracking
                  ElevatedButton.icon(
                    onPressed: _toggleTracking,
                    icon: Icon(_isBackgroundTracking ? Icons.stop : Icons.play_arrow),
                    label: Text(_isBackgroundTracking ? 'STOP TRACKING' : 'START TRACKING'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBackgroundTracking ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  OutlinedButton.icon(
                    onPressed: _sendTestNotification,
                    icon: const Icon(Icons.send),
                    label: const Text('Send Test Notification'),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    _isBackgroundTracking 
                      ? 'Tracking active. Notification will be sent when bus reaches target.'
                      : 'Set locations and start tracking to enable automatic notifications.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    textAlign: TextAlign.center,
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
