import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
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
  bool _hasNotified = false;

  @override
  void dispose() {
    _targetSubscription?.cancel();
    _targetIdController.dispose();
    super.dispose();
  }

  void _showArrivalDialog(String targetName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚌 Bus Arrived!'),
        content: Text('The bus has reached $targetName'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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
    _hasNotified = false;
    
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
          
          // Show dialog when reached becomes true (only once)
          if (data['reached'] == true && !_hasNotified) {
            _hasNotified = true;
            _showArrivalDialog(data['name']);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🚌 Bus arrived at ${data['name']}!'),
                backgroundColor: Colors.green,
              ),
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
      _hasNotified = false;
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
            TextField(
              controller: _targetIdController,
              decoration: const InputDecoration(
                labelText: 'Target ID',
                border: OutlineInputBorder(),
                hintText: 'Enter the target ID from bus app',
              ),
            ),
            const SizedBox(height: 16),
            
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
            
            if (_isListening) ...[
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
                      if (_targetData != null) ...[
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
                    Text('4. You\'ll get a popup when the bus arrives'),
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
