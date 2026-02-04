import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📨 Background message received: ${message.messageId}');
  
  // Initialize TTS for background
  final FlutterTts tts = FlutterTts();
  await tts.setLanguage("en-US");
  await tts.setSpeechRate(0.5);
  await tts.setVolume(1.0);
  await tts.setPitch(1.0);
  
  // Get place name and speak immediately
  final placeName = message.data['location_name'] ?? 'your destination';
  final speechText = 'Your bus has reached $placeName. Please get ready.';
  
  print('🔊 Background TTS: $speechText');
  await tts.speak(speechText);
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
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    _fcmToken = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $_fcmToken');
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleMessage(message);
    });
    
    // Handle messages when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📨 App opened from notification');
      final placeName = message.data['location_name'] ?? 'your destination';
      _speak('Your bus has reached $placeName. Please get ready.');
      _handleMessage(message);
    });
    
    // Handle initial message if app was opened from notification
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('📨 App launched from notification');
      final placeName = initialMessage.data['location_name'] ?? 'your destination';
      _speak('Your bus has reached $placeName. Please get ready.');
      _handleMessage(initialMessage);
    }
    
    setState(() {});
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      
      // Test if TTS is working
      bool isLanguageAvailable = await _tts.isLanguageAvailable("en-US");
      print('TTS Language available: $isLanguageAvailable');
      
      // Set up TTS completion handler
      _tts.setCompletionHandler(() {
        print('TTS completed');
      });
      
      _tts.setErrorHandler((msg) {
        print('TTS Error: $msg');
      });
      
    } catch (e) {
      print('TTS initialization error: $e');
    }
  }

  void _handleMessage(RemoteMessage message) {
    print('📨 Foreground message received: ${message.data}');
    
    final placeName = message.data['location_name'] ?? 'your destination';
    final timestamp = DateTime.now().toString().substring(0, 19);
    
    setState(() {
      _notifications.insert(0, '$timestamp: Bus arrived at $placeName');
    });
    
    // Speak immediately without delay
    _speak('Your bus has reached $placeName. Please get ready.');
    
    // Show dialog after speaking starts
    Future.delayed(const Duration(milliseconds: 100), () {
      _showArrivalDialog(placeName);
    });
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
    try {
      print('🔊 Speaking: $text');
      
      // Stop any current speech
      await _tts.stop();
      
      // Speak the text
      var result = await _tts.speak(text);
      print('TTS Result: $result');
      
    } catch (e) {
      print('TTS speak error: $e');
    }
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
            
            const SizedBox(height: 8),
            
            OutlinedButton.icon(
              onPressed: () => _speak('Your bus has reached School Gate. Please get ready.'),
              icon: const Icon(Icons.directions_bus),
              label: const Text('Test Arrival Voice'),
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