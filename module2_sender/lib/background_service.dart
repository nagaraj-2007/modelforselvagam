
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
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Bus Tracking Active',
        initialNotificationContent: 'Monitoring location...',
        foregroundServiceNotificationId: notificationId,
      ),
        iosConfiguration: IosConfiguration(
        autoStart: true,
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

    // High accuracy location tracking with 20m distance filter
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
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
        _sendCurrentLocationPeriodically(position, service, notificationPlugin);
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
      
      final targetLocsJson = prefs.getString('targetLocations');
      final selectedTargetIndex = prefs.getInt('selectedTargetIndex');
      final fcmToken = prefs.getString('fcmToken');
      final serviceAccountJson = prefs.getString('serviceAccountJson');

      print("DEBUG: Current position: ${position.latitude}, ${position.longitude}");
      print("DEBUG: targetLocsJson exists: ${targetLocsJson != null}");
      print("DEBUG: selectedTargetIndex: $selectedTargetIndex");
      print("DEBUG: fcmToken exists: ${fcmToken != null}");
      print("DEBUG: serviceAccountJson exists: ${serviceAccountJson != null}");

      if (targetLocsJson == null || selectedTargetIndex == null || fcmToken == null || serviceAccountJson == null) {
        print("DEBUG: Missing required data - exiting");
        return;
      }

      final List<dynamic> targetLocations = jsonDecode(targetLocsJson);
      if (selectedTargetIndex >= targetLocations.length) {
        return;
      }

      Map<String, dynamic> targetLocation = Map<String, dynamic>.from(targetLocations[selectedTargetIndex]);

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetLocation['lat'],
        targetLocation['lng'],
      );

      print("DEBUG: Distance to target: ${distance.toStringAsFixed(1)}m");
      print("DEBUG: Target already reached: ${targetLocation['reached']}");

      // Check if within 100 meters
      if (distance <= 100.0) {
        print("DEBUG: Within 100m! Checking if already reached...");
        
        // Check if already reached to prevent repeated triggers
        if (targetLocation['reached'] == true) {
          print("DEBUG: Target already reached - skipping notification");
          return; // Already notified, don't send again
        }
        
        print("DEBUG: Target not reached yet - checking cooldown...");
        
        // Check cooldown - send every 5 seconds while in range
        final lastNotificationTime = prefs.getInt('lastNotificationTime') ?? 0;
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        
        print("DEBUG: Cooldown check - Last: $lastNotificationTime, Current: $currentTime");
        
        if (currentTime - lastNotificationTime < 5000) {
          print("DEBUG: Still in cooldown - skipping");
          return; // Still in cooldown period
        }
        
        print("DEBUG: Sending FCM notification now!");
        
        // Mark as reached to prevent repeated triggers
        targetLocations[selectedTargetIndex]['reached'] = true;
        await prefs.setString('targetLocations', jsonEncode(targetLocations));
        
        // Update last notification time
        await prefs.setInt('lastNotificationTime', currentTime);
        
        // Send FCM notification
        await _sendFCM(serviceAccountJson, fcmToken, targetLocation['name']);
        
        // Show local notification
        notificationPlugin.show(
          1000,
          "TARGET REACHED!",
          "Within 100m of ${targetLocation['name']} - Notification sent",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              notificationChannelId, 
              'Alerts',
              importance: Importance.max,
              priority: Priority.max,
            )
          ),
        );
      } else {
        print("DEBUG: Outside 100m range - distance: ${distance.toStringAsFixed(1)}m");
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

  static Future<void> sendCurrentLocation(String serviceAccountJson, String fcmToken, Position position) async {
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
              'title': 'Bus Current Location',
              'body': 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}',
            },
            'data': {
              'type': 'current_location',
              'latitude': position.latitude.toString(),
              'longitude': position.longitude.toString(),
            },
            'android': {
              'priority': 'high',
            }
          },
        }),
      );

      client.close();
    } catch (e) {
      throw Exception('Failed to send location: $e');
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

  static Future<void> _sendCurrentLocationPeriodically(Position position, ServiceInstance service, FlutterLocalNotificationsPlugin notificationPlugin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      
      final fcmToken = prefs.getString('fcmToken');
      final serviceAccountJson = prefs.getString('serviceAccountJson');
      
      if (fcmToken == null || serviceAccountJson == null) {
        return;
      }
      
      // Check cooldown for current location notifications
      final lastCurrentLocationTime = prefs.getInt('lastCurrentLocationTime') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      if (currentTime - lastCurrentLocationTime < 5000) {
        return; // Still in cooldown period
      }
      
      // Update last current location notification time
      await prefs.setInt('lastCurrentLocationTime', currentTime);
      
      // Send current location FCM notification
      await sendCurrentLocation(serviceAccountJson, fcmToken, position);
      
    } catch (e) {
      notificationPlugin.show(
        995,
        "Current Location Error",
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
