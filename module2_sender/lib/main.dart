
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
  
  List<Map<String, dynamic>> _targetLocations = [];
  int? _selectedTargetIndex;

  @override
  void initState() {
    super.initState();
    _stopAnyExistingService(); // Stop any service from previous session
    _requestInitialPermissions(); // Request permissions at startup
    _loadStoredData();
    _startStatusPoller();
    _getCurrentLocation();
  }

  Future<void> _requestInitialPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required. Please enable it in app settings.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      print('Permission request error: $e');
    }
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
      
      // Check if any target was reached and update UI
      final targetLocsJson = prefs.getString('targetLocations');
      if (targetLocsJson != null) {
        final List<dynamic> targets = jsonDecode(targetLocsJson);
        setState(() {
          _targetLocations = targets.map((e) => Map<String, dynamic>.from(e)).toList();
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
      // Request permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return;
      }

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
            SnackBar(
              content: const Text('Background location is required. Please select "Allow all the time" in settings.'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
      }
    }
    
    await Permission.notification.request();
    
    // Check battery optimization
    _checkBatteryOptimization();
  }
  
  Future<void> _checkBatteryOptimization() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShownDialog = prefs.getBool('batteryOptimizationDialogShown') ?? false;
    
    if (!hasShownDialog && mounted) {
      await prefs.setBool('batteryOptimizationDialogShown', true);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.battery_alert, color: Colors.orange),
              SizedBox(width: 8),
              Text('Important Setup'),
            ],
          ),
          content: const Text(
            'Your phone may stop background tracking and notifications to save battery.\n\n'
            'To ensure you receive notifications when the bus arrives, please disable battery optimization for this app.\n\n'
            'Steps:\n'
            '1. Tap "Open Settings" below\n'
            '2. Find "Battery" or "Battery optimization"\n'
            '3. Select "Don\'t optimize" or "Allow"'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('fcmToken');
    if (storedToken != null && storedToken.isNotEmpty) {
       _tokenController.text = storedToken;
    }
    
    final targetLocsJson = prefs.getString('targetLocations');
    if (targetLocsJson != null) {
      final List<dynamic> decoded = jsonDecode(targetLocsJson);
      setState(() {
        _targetLocations = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    }
    
    final storedIndex = prefs.getInt('selectedTargetIndex');
    if (storedIndex != null && storedIndex < _targetLocations.length) {
      _selectedTargetIndex = storedIndex;
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcmToken', _tokenController.text.trim());
    
    await prefs.setString('targetLocations', jsonEncode(_targetLocations));
    if (_selectedTargetIndex != null) {
      await prefs.setInt('selectedTargetIndex', _selectedTargetIndex!);
    }
    
    try {
      final serviceAccountJson = await rootBundle.loadString('assets/service-account-key.json');
      await prefs.setString('serviceAccountJson', serviceAccountJson);
    } catch (e) {
      print("Error loading service account: $e");
    }
  }

  Future<void> _addTargetAtLocation(LatLng position) async {
    String? name = await _showNameDialog('Target ${_targetLocations.length + 1}');
    if (name == null) return;
    
    setState(() {
      _targetLocations.add({
        'name': name,
        'lat': position.latitude,
        'lng': position.longitude,
        'reached': false,
      });
    });
    
    await _saveData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Target "$name" added at ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<String?> _showNameDialog(String defaultName) async {
    TextEditingController nameController = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Location Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteTarget(int index) {
    setState(() {
      _targetLocations.removeAt(index);
      if (_selectedTargetIndex == index) {
        _selectedTargetIndex = null;
      } else if (_selectedTargetIndex != null && _selectedTargetIndex! > index) {
        _selectedTargetIndex = _selectedTargetIndex! - 1;
      }
      // Reset if selected index is now out of bounds
      if (_selectedTargetIndex != null && _selectedTargetIndex! >= _targetLocations.length) {
        _selectedTargetIndex = null;
      }
    });
    _saveData();
  }

  Future<void> _editTarget(int index) async {
    String? newName = await _showNameDialog(_targetLocations[index]['name']);
    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _targetLocations[index]['name'] = newName;
      });
      _saveData();
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

      if (_selectedTargetIndex == null || _targetLocations.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a target location first')),
        );
        return;
      }

      await _requestPermissions();
      await _saveData();
      
      final service = FlutterBackgroundService();
      await service.startService();
      setState(() => _isBackgroundTracking = true);
      
      // If already at target location, trigger immediately
      if (_currentPosition != null && _selectedTargetIndex != null) {
        final target = _targetLocations[_selectedTargetIndex!];
        double distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          target['lat'],
          target['lng'],
        );
        
        if (distance <= 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Already at ${target['name']}! Distance: ${distance.toStringAsFixed(0)}m - Notification will be sent automatically')),
          );
        }
      }
    }
  }

  Future<void> _sendCurrentLocation() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token required')));
      return;
    }

    try {
      // Request permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final serviceAccountJson = await rootBundle.loadString('assets/service-account-key.json');
      
      await BackgroundService.sendCurrentLocation(serviceAccountJson, token, position);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Current location sent: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  void _clearAllTargets() {
    setState(() {
      _targetLocations.clear();
      _selectedTargetIndex = null;
    });
    _saveData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All targets cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {};
    
    for (int i = 0; i < _targetLocations.length; i++) {
      final target = _targetLocations[i];
      markers.add(Marker(
        markerId: MarkerId('target_$i'),
        position: LatLng(target['lat'], target['lng']),
        infoWindow: InfoWindow(title: target['name']),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          i == _selectedTargetIndex 
            ? (target['reached'] == true ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueBlue)
            : BitmapDescriptor.hueRed,
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
            icon: const Icon(Icons.clear_all, color: Colors.white),
            onPressed: _clearAllTargets,
            tooltip: 'Clear All Targets',
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
              onLongPress: _addTargetAtLocation,
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
                  

                  // Target Locations List
                  if (_targetLocations.isNotEmpty) ...[
                    const Text('Target Locations:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                  ],
                  if (_targetLocations.isNotEmpty)
                    ..._targetLocations.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> target = entry.value;
                      bool isSelected = index == _selectedTargetIndex;
                      
                      return Card(
                        color: isSelected 
                          ? (target['reached'] == true ? Colors.orange[50] : Colors.blue[50])
                          : Colors.grey[50],
                        child: ListTile(
                          leading: Icon(
                            target['reached'] == true ? Icons.check_circle : Icons.location_on,
                            color: isSelected 
                              ? (target['reached'] == true ? Colors.orange : Colors.blue)
                              : Colors.grey,
                          ),
                          title: Text(target['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Lat: ${target['lat'].toStringAsFixed(6)}\nLng: ${target['lng'].toStringAsFixed(6)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_currentPosition != null && target['reached'] != true)
                                Text(
                                  '${Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, target['lat'], target['lng']).toStringAsFixed(0)}m',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  setState(() {
                                    _selectedTargetIndex = index;
                                  });
                                  await _saveData();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Selected ${target['name']} as target')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected ? Colors.orange : Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                child: Text(isSelected ? 'Selected' : 'Select', style: const TextStyle(fontSize: 12)),
                              ),
                              PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'select',
                                    child: Text(isSelected ? 'Deselect' : 'Select'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit Name'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                                onSelected: (value) {
                                  switch (value) {
                                    case 'select':
                                      setState(() {
                                        _selectedTargetIndex = isSelected ? null : index;
                                      });
                                      _saveData();
                                      break;
                                    case 'edit':
                                      _editTarget(index);
                                      break;
                                    case 'delete':
                                      _deleteTarget(index);
                                      break;
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  
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
                    onPressed: _sendCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Send Current Location'),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        Position position = await Geolocator.getCurrentPosition();
                        // Create target 10 meters away (very close for testing)
                        double testLat = position.latitude + 0.00009; // ~10m north
                        double testLng = position.longitude;
                        
                        setState(() {
                          _targetLocations.add({
                            'name': 'Test Target (10m away)',
                            'lat': testLat,
                            'lng': testLng,
                            'reached': false,
                          });
                          _selectedTargetIndex = _targetLocations.length - 1;
                        });
                        
                        await _saveData();
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Test target created 10m away and selected')),
                        );
                        
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(position.latitude, position.longitude),
                            18,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Add Test Target (10m away)'),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (_selectedTargetIndex != null && _selectedTargetIndex! < _targetLocations.length) {
                        final target = _targetLocations[_selectedTargetIndex!];
                        try {
                          final serviceAccountJson = await rootBundle.loadString('assets/service-account-key.json');
                          await BackgroundService.sendCurrentLocation(serviceAccountJson, _tokenController.text.trim(), _currentPosition!);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Force notification sent for ${target['name']}')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.notification_important),
                    label: const Text('Force Send Target Notification'),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    _isBackgroundTracking 
                      ? (_selectedTargetIndex != null && _selectedTargetIndex! < _targetLocations.length
                          ? 'Tracking active. Notification will be sent when reaching "${_targetLocations[_selectedTargetIndex!]['name']}".'
                          : 'Tracking active but no target selected.')
                      : 'Long press on map to add targets, select one, and start tracking.',
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
