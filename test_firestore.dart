import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Add a test document to Firestore
  await addTestDocument();
  
  runApp(const MyApp());
}

Future<void> addTestDocument() async {
  try {
    DocumentReference docRef = await FirebaseFirestore.instance
        .collection('targets')
        .add({
      'name': 'Test Bus Stop',
      'location': const GeoPoint(10.081642, 78.746657), // Sample coordinates
      'radius': 100,
      'reached': false,
      'reachedAt': null,
    });
    
    print('✅ Test document added with ID: ${docRef.id}');
    print('📍 Location: Test Bus Stop at (10.081642, 78.746657)');
    print('🎯 You can now see this in Firebase Console > Firestore Database > targets collection');
  } catch (e) {
    print('❌ Error adding test document: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Firestore Test')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 64),
              SizedBox(height: 16),
              Text(
                'Test document added to Firestore!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Check Firebase Console > Firestore Database'),
            ],
          ),
        ),
      ),
    );
  }
}