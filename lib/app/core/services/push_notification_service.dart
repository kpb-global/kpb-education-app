import 'dart:developer' as dev;
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../navigation/app_navigation.dart';

/// Background handler must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  dev.log('Handling a background message: ${message.messageId}');
  // Initialize minimal services if necessary (e.g. Hive for local caching)
}

/// Service to handle Firebase Cloud Messaging (Push Notifications).
class PushNotificationService extends GetxService {
  static PushNotificationService get instance => Get.find<PushNotificationService>();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  @override
  void onInit() {
    super.onInit();
    _initPushNotifications();
  }

  Future<void> _initPushNotifications() async {
    try {
      // Android 13+: POST_NOTIFICATIONS must be granted for heads-up / shade delivery.
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      }

      // 1. Request Permission (APNs on iOS; no-op on Android for system dialog)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      dev.log('User granted permission: ${settings.authorizationStatus}');

      // 2. Setup Background Handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        dev.log('Got a message whilst in the foreground!');
        dev.log('Message data: ${message.data}');

        if (message.notification != null) {
          // You could show a local notification here using flutter_local_notifications
          Get.snackbar(
            message.notification!.title ?? 'Nouvelle notification',
            message.notification!.body ?? '',
            snackPosition: SnackPosition.TOP,
            duration: const Duration(seconds: 4),
            onTap: (_) => _handleMessageRouting(message),
          );
        }
      });

      // 4. Handle Notification Taps (App in Background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        dev.log('A new onMessageOpenedApp event was published!');
        _handleMessageRouting(message);
      });

      // 5. Handle Initial Message (App Terminated)
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        // Delay routing until UI is fully initialized
        Future.delayed(const Duration(seconds: 1), () {
          _handleMessageRouting(initialMessage);
        });
      }

    } catch (e) {
      dev.log('Failed to initialize push notifications: $e');
    }
  }

  /// Extracts routing information from the FCM payload and navigates.
  /// Expects a `route` key in the data payload (e.g. `route`: `/cases/abc123`).
  /// Unknown routes are ignored to avoid GetX navigation exceptions.
  void _handleMessageRouting(RemoteMessage message) {
    AppNavigation.toExternalRoute(message.data['route']);
  }

  /// Retrieves the FCM token to save it to the backend.
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      dev.log('Failed to get FCM token: $e');
      return null;
    }
  }
}
