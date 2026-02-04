import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
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
  String? _fcmToken;
  final FlutterTts _tts = FlutterTts();
  List<String> _notifications = [];

  @override
  void initState() {
    super.initState();
    _initFCM();
    _initTts();
  }

  Future<void> _initFCM() async {
    await FirebaseMessaging.instance.requestPermission();
    
    _fcmToken = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $_fcmToken');
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleMessage(message);
    });
    
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message);
    });
    
    setState(() {});
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  void _handleMessage(RemoteMessage message) {
    final placeName = message.data['location_name'] ?? 'your destination';
    final timestamp = DateTime.now().toString().substring(0, 19);
    
    setState(() {
      _notifications.insert(0, '$timestamp: Bus arrived at $placeName');
    });
    
    _showArrivalDialog(placeName);
    _speak('Your bus has reached $placeName. Please get ready.');
  }

  void _showArrivalDialog(String placeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚌 Bus Arrived!'),
        content: Text('The bus has reached $placeName'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FCM Token:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _fcmToken ?? 'Loading...',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            OutlinedButton.icon(
              onPressed: () => _speak('Test message: Your bus will reach in a few minutes.'),
              icon: const Icon(Icons.volume_up),
              label: const Text('Test Voice'),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Notifications:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            
            const SizedBox(height: 8),
            
            Expanded(
              child: _notifications.isEmpty
                  ? const Center(
                      child: Text('No notifications yet'),
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.notifications),
                            title: Text(_notifications[index]),
                          ),
                        );
                      },
                    ),
            ),
            
            const SizedBox(height: 16),
            
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
                    Text('1. Share your FCM Token with the bus driver'),
                    Text('2. The bus driver will use it to send notifications'),
                    Text('3. You\'ll get push notifications when the bus arrives'),
                    Text('4. Notifications include voice announcements'),
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