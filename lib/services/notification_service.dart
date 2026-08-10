import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) {
        final payload = notificationResponse.payload;
        if (payload != null) {
          _navigateToDeepLink(navigatorKey, payload);
        }
      },
    );

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel', // id
              'High Importance Notifications', // title
              channelDescription: 'This channel is used for important notifications.',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          payload: message.data['requestId'], // Payload to pass the request ID
        );
      }
    });

    // App opened from background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['requestId'] != null) {
        _navigateToDeepLink(navigatorKey, message.data['requestId']);
      }
    });
  }

  static Future<void> setupTerminatedState(GlobalKey<NavigatorState> navigatorKey) async {
    // App opened from terminated state
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      if (initialMessage.data['requestId'] != null) {
         // Use a slight delay to ensure context is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToDeepLink(navigatorKey, initialMessage.data['requestId']);
        });
      }
    }
  }

  static void _navigateToDeepLink(GlobalKey<NavigatorState> navigatorKey, String requestId) {
    // Navigate to Donor Tracking Screen or Request Detail Screen
    if (navigatorKey.currentState != null) {
      // Typically we'd go to a detail screen. Since I don't see a detail screen,
      // I'll assume we navigate to tracking screen or we need to pass the request id
      // to a specialized screen. Let's create a route for tracking or details.
      navigatorKey.currentState?.pushNamed('/request_details', arguments: requestId);
    }
  }
}
