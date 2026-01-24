
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundService {
  static const String notificationChannelId = 'location_tracking_channel';
  static const int notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Bus Location Tracking',
      description: 'Tracks bus location to send arrival notifications.',
      importance: Importance.max, 
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    if (Platform.isIOS || Platform.isAndroid) {
      await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    }

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Bus Tracking Active',
        initialNotificationContent: 'Monitoring location...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: (instance) => true,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final FlutterLocalNotificationsPlugin notificationPlugin = FlutterLocalNotificationsPlugin();
    
    String lastStatus = "Initializing...";

    // Update notification every 5 seconds
    Timer.periodic(const Duration(seconds: 5), (timer) async {
       if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          notificationPlugin.show(
            notificationId,
            'Bus Tracking Active',
            lastStatus,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                notificationChannelId,
                'Bus Location Tracking',
                icon: '@mipmap/ic_launcher',
                ongoing: true,
                showWhen: false,
                onlyAlertOnce: true,
                priority: Priority.max,
                importance: Importance.max,
              ),
            ),
          );
        }
      }
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      lastStatus = "ERROR: Location permission denied!";
      return;
    }

    lastStatus = "GPS enabled, waiting for fix...";

    // High accuracy location tracking
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    bool isFirstUpdate = true;
    
    Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        if (isFirstUpdate) {
          lastStatus = "GPS LOCKED! Monitoring...";
          isFirstUpdate = false;
        }
        
        lastStatus = "Tracking: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
        _checkTargetLocation(position, service, notificationPlugin);
      },
      onError: (error) {
        lastStatus = "GPS ERROR: $error";
      },
    );
  }

  static Future<void> _checkTargetLocation(Position position, ServiceInstance service, FlutterLocalNotificationsPlugin notificationPlugin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      
      final targetLocJson = prefs.getString('targetLocation');
      final fcmToken = prefs.getString('fcmToken');
      final serviceAccountJson = prefs.getString('serviceAccountJson');
      final targetReached = prefs.getBool('targetReached') ?? false;

      if (targetLocJson == null || fcmToken == null || serviceAccountJson == null) {
        return;
      }

      if (targetReached) {
        return; // Already reached, don't check again
      }

      Map<String, dynamic> targetLocation = jsonDecode(targetLocJson);
      double targetRadius = 150.0; // 150 meters

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLocation['lat'],
        targetLocation['lng'],
      );

      // Show proximity alert
      if (distance < 300) {
        notificationPlugin.show(
          999,
          "Approaching Target!",
          "Distance: ${distance.toStringAsFixed(0)}m (will notify at 150m)",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              notificationChannelId,
              'Alerts',
              importance: Importance.max,
              priority: Priority.max,
            )
          ),
        );
      }

      // Check if target reached
      if (distance <= targetRadius) {
        // Mark as reached
        await prefs.setBool('targetReached', true);
        targetLocation['reached'] = true;
        await prefs.setString('targetLocation', jsonEncode(targetLocation));
        
        // Show local notification
        notificationPlugin.show(
          1000,
          "TARGET REACHED!",
          "Sending notification to passengers...",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              notificationChannelId, 
              'Alerts',
              importance: Importance.max,
              priority: Priority.max,
            )
          ),
        );
        
        // Send FCM notification
        await _sendFCM(serviceAccountJson, fcmToken, targetLocation['name']);
        
        // Notify UI
        service.invoke("update", {"targetReached": true});
      }
    } catch (e) {
      notificationPlugin.show(
        998,
        "Background Error",
        e.toString(),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            notificationChannelId,
            'Errors',
          )
        ),
      );
    }
  }

  static Future<void> _sendFCM(String serviceAccountJson, String fcmToken, String locationName) async {
    try {
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
            'token': fcmToken,
            'notification': {
              'title': 'Bus Reached Your Destination!',
              'body': 'The bus has arrived at $locationName',
            },
            'data': {
              'type': 'destination_reached',
              'location_name': locationName,
            },
            'android': {
              'priority': 'high',
            }
          },
        }),
      );

      // Show FCM result
      final notificationPlugin = FlutterLocalNotificationsPlugin();
      notificationPlugin.show(
        997,
        "Notification Sent!",
        "Status: ${response.statusCode} - Passengers notified",
        const NotificationDetails(
          android: AndroidNotificationDetails(
            notificationChannelId,
            'FCM Status',
            importance: Importance.max,
          )
        ),
      );

      client.close();
    } catch (e) {
      final notificationPlugin = FlutterLocalNotificationsPlugin();
      notificationPlugin.show(
        996,
        "FCM Error",
        e.toString(),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            notificationChannelId,
            'Errors',
          )
        ),
      );
    }
  }
}
