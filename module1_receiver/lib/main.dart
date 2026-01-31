import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initializeNotifications();
  runApp(const MyApp());
}

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Passenger App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const PassengerScreen(),
    );
  }
}

class PassengerScreen extends StatefulWidget {
  const PassengerScreen({super.key});

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  final TextEditingController _targetIdController = TextEditingController();
  StreamSubscription<DocumentSnapshot>? _targetSubscription;
  Map<String, dynamic>? _targetData;
  String? _currentTargetId;
  bool _isListening = false;

  @override
  void dispose() {
    _targetSubscription?.cancel();
    _targetIdController.dispose();
    super.dispose();
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'bus_arrival',
      'Bus Arrival Notifications',
      channelDescription: 'Notifications when bus reaches destination',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  void _startListening() {
    final targetId = _targetIdController.text.trim();
    if (targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a target ID')),
      );
      return;
    }

    _targetSubscription?.cancel();
    
    _targetSubscription = FirebaseFirestore.instance
        .collection('targets')
        .doc(targetId)
        .snapshots()
        .listen(
      (DocumentSnapshot snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          setState(() {
            _targetData = data;
          });
          
          // Show notification when reached becomes true
          if (data['reached'] == true && _isListening) {
            _showNotification(
              'Bus Arrived!',
              'The bus has reached ${data['name']}',
            );
          }
        } else {
          setState(() {
            _targetData = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target not found')),
          );
        }
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      },
    );

    setState(() {
      _currentTargetId = targetId;
      _isListening = true;
    });
  }

  void _stopListening() {
    _targetSubscription?.cancel();
    setState(() {
      _isListening = false;
      _currentTargetId = null;
      _targetData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passenger App'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Target ID Input
            TextField(
              controller: _targetIdController,
              decoration: const InputDecoration(
                labelText: 'Target ID',
                border: OutlineInputBorder(),
                hintText: 'Enter the target ID from bus app',
              ),
            ),
            const SizedBox(height: 16),
            
            // Listen/Stop Button
            ElevatedButton.icon(
              onPressed: _isListening ? _stopListening : _startListening,
              icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
              label: Text(_isListening ? 'Stop Listening' : 'Start Listening'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Status Card
            if (_isListening) ..[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Listening to: $_currentTargetId',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_targetData != null) ..[
                        Text('Target: ${_targetData!['name']}'),
                        Text(
                          'Status: ${_targetData!['reached'] ? 'Reached ✅' : 'Not Reached ⏳'}',
                          style: TextStyle(
                            color: _targetData!['reached'] ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_targetData!['reachedAt'] != null)
                          Text(
                            'Reached at: ${(_targetData!['reachedAt'] as Timestamp).toDate()}',
                          ),
                      ] else
                        const Text('Loading target data...'),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Instructions
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to use:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text('1. Get the Target ID from the bus driver'),
                    Text('2. Enter the Target ID above'),
                    Text('3. Tap "Start Listening"'),
                    Text('4. You\'ll get a notification when the bus arrives'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
