import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';

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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final prefs = await SharedPreferences.getInstance();
  String? targetId = prefs.getString('selectedTargetId');
  
  if (targetId == null) {
    service.stopSelf();
    return;
  }

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('targets')
          .doc(targetId)
          .get();
      
      if (!doc.exists) {
        timer.cancel();
        service.stopSelf();
        return;
      }
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (data['reached'] == true) {
        timer.cancel();
        service.stopSelf();
        return;
      }
      
      GeoPoint targetLocation = data['location'];
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLocation.latitude,
        targetLocation.longitude,
      );
      
      service.invoke('update', {
        'distance': distance.round(),
        'lat': position.latitude,
        'lng': position.longitude,
      });
      
      if (distance <= (data['radius'] ?? 100)) {
        await FirebaseFirestore.instance
            .collection('targets')
            .doc(targetId)
            .update({
          'reached': true,
          'reachedAt': FieldValue.serverTimestamp(),
        });
        
        timer.cancel();
        service.stopSelf();
      }
    } catch (e) {
      print('Background service error: $e');
    }
  });
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
  String? _selectedTargetId;
  Map<String, dynamic>? _selectedTarget;
  double? _currentDistance;
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadSelectedTarget();
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

  Future<void> _loadSelectedTarget() async {
    final prefs = await SharedPreferences.getInstance();
    String? targetId = prefs.getString('selectedTargetId');
    
    if (targetId != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('targets')
          .doc(targetId)
          .get();
      
      if (doc.exists) {
        setState(() {
          _selectedTargetId = targetId;
          _selectedTarget = doc.data() as Map<String, dynamic>;
        });
      }
    }
  }

  Future<void> _createTargetAtLocation(LatLng position, [String? customName]) async {
    String targetName;
    
    if (customName != null) {
      targetName = customName;
    } else {
      // Show dialog to enter target name
      targetName = await _showNameDialog() ?? 'Target ${DateTime.now().millisecondsSinceEpoch}';
    }

    try {
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('targets')
          .add({
        'name': targetName,
        'location': GeoPoint(position.latitude, position.longitude),
        'radius': 100,
        'reached': false,
        'reachedAt': null,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedTargetId', docRef.id);
      
      setState(() {
        _selectedTargetId = docRef.id;
        _selectedTarget = {
          'name': targetName,
          'location': GeoPoint(position.latitude, position.longitude),
          'radius': 100,
          'reached': false,
        };
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Target "$targetName" created! Share ID: ${docRef.id}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating target: $e')),
      );
    }
  }

  Future<String?> _showNameDialog() async {
    final TextEditingController nameController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Target Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Target Name',
            hintText: 'e.g., School Gate, Bus Stop A',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              Navigator.pop(context, name.isEmpty ? null : name);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTracking() async {
    if (_selectedTargetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a target first')),
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
            height: 300,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null
                    ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                    : const LatLng(0, 0),
                zoom: 15,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: _createTargetAtLocation,
              myLocationEnabled: true,
              markers: _selectedTarget != null
                  ? {
                      Marker(
                        markerId: const MarkerId('target'),
                        position: LatLng(
                          _selectedTarget!['location'].latitude,
                          _selectedTarget!['location'].longitude,
                        ),
                        infoWindow: InfoWindow(title: _selectedTarget!['name']),
                      ),
                    }
                  : {},
            ),
          ),
          
          // Controls
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_currentPosition != null) {
                              _createTargetAtLocation(
                                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Getting location...')),
                              );
                            }
                          },
                          icon: const Icon(Icons.my_location),
                          label: const Text('Create Here'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Selected Target Info
                  if (_selectedTarget != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target: ${_selectedTarget!['name']}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('ID: $_selectedTargetId'),
                            Text('Status: ${_selectedTarget!['reached'] ? 'Reached' : 'Not Reached'}'),
                            if (_currentDistance != null)
                              Text('Distance: ${_currentDistance!.toStringAsFixed(0)}m'),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap anywhere on the map to create a target',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            SelectableText(
                              _selectedTargetId!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Tracking Button
                  ElevatedButton.icon(
                    onPressed: _toggleTracking,
                    icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                    label: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTracking ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Instructions
                  const Card(
                    color: Colors.blue,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Icon(Icons.info, color: Colors.white),
                          SizedBox(height: 8),
                          Text(
                            'How to create targets:',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '• Tap anywhere on the map\n• Or use "Create Here" for current location',
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
