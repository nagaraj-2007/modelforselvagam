import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure we can use plugins in background
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print("Background Message Received: ${message.notification?.title}");
  
  final tts = FlutterTts();
  await tts.setLanguage("en-US");
  await tts.setSpeechRate(0.5);
  await tts.setVolume(1.0);
  await tts.setPitch(1.0);
  
  // Important for Android: wait for completion to avoid isolate termination
  await tts.awaitSpeakCompletion(true);
  
  // Create a combined text to speak
  String speechText = "";
  if (message.notification?.title != null) {
      speechText += "${message.notification!.title}. ";
  }
  if (message.notification?.body != null) {
      speechText += "${message.notification!.body}";
  }
  
  // Fallback to data if notification is empty
  if (speechText.trim().isEmpty && message.data.isNotEmpty) {
      if (message.data.containsKey('location_name')) {
        speechText = "Bus reaching at ${message.data['location_name']}";
      }
  }

  if (speechText.isNotEmpty) {
    print("Speaking in background: $speechText");
    try {
      await tts.speak(speechText);
      // Wait a bit more to ensure it actually starts
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      print("TTS Background Error: $e");
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterTts tts = FlutterTts();
  String? _token;
  String _lastMessage = "No messages yet";
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initTTS();
    _setupFCM();
  }

  Future<void> _initTTS() async {
    await tts.setLanguage("en-US");
    await tts.setSpeechRate(0.5);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
    await tts.awaitSpeakCompletion(true);
    
    tts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });

    tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });

    tts.setErrorHandler((msg) {
       if (mounted) setState(() => _isSpeaking = false);
       print("TTS Error: $msg");
    });
  }

  Future<void> _setupFCM() async {
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    print('User granted permission: ${settings.authorizationStatus}');

    _token = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $_token');
    if (mounted) setState(() {});
    
    // Foreground handler
    FirebaseMessaging.onMessage.listen((message) {
      print('Foreground Message Received');
      
      String title = message.notification?.title ?? "Notification";
      String body = message.notification?.body ?? "";
      
      // Fallback to data
      if (body.isEmpty && message.data.isNotEmpty) {
        if (message.data.containsKey('location_name')) {
          body = "Bus reached ${message.data['location_name']}";
        }
      }

      String fullText = "$title. $body";
      
      if (mounted) {
        setState(() {
          _lastMessage = fullText;
        });
      }
      
      _speak(fullText);
    });
  }
  
  Future<void> _speak(String text) async {
    await tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
      home: Scaffold(
        appBar: AppBar(title: const Text('Module 1: Receiver (Voice)')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isSpeaking ? Icons.record_voice_over : Icons.notifications_active,
                  size: 80,
                  color: _isSpeaking ? Colors.green : Colors.deepPurple,
                ),
                const SizedBox(height: 20),
                Text(
                  _isSpeaking ? "Speaking..." : "Ready to Receive",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                const Text('Last Received Message:', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    _lastMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 30),
                if (_token != null) ...[
                  const Text('Your FCM Token:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      // Copy to clipboard
                      // Clipboard.setData(ClipboardData(text: _token!)); // requires flutter/services
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _token!, 
                        style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text("Copy this token to Module 2", style: TextStyle(fontSize: 10)),
                  ),
                ] else
                   const CircularProgressIndicator(),
                   
                const SizedBox(height: 40),
                ElevatedButton(
                   onPressed: () => _speak("This is a test of the voice notification system."),
                   child: const Text("Test Voice"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
