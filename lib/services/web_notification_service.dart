import '../core/logging_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Web Notification Service for Browser Push Notifications
class WebNotificationService {
  static final WebNotificationService _instance =
      WebNotificationService._internal();
  factory WebNotificationService() => _instance;
  WebNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize web notifications
  Future<void> initialize() async {
    // Only run on web
    if (!kIsWeb) return;

    try {
      Log.i('WebNotificationService', 'Initializing browser notifications...');

      // Request permission for browser notifications
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      Log.i('WebNotificationService', 'Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        String? token = await _messaging.getToken(
          vapidKey: const String.fromEnvironment('VAPID_KEY'),
        );

        if (token != null) {
          await _saveTokenToFirestore(token);
          Log.i('WebNotificationService', 'Browser notifications enabled!');
        }
      } else {
        Log.w('WebNotificationService', 'Notification permission denied');
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        Log.i('WebNotificationService', 'Foreground message: ${message.notification?.title}');
        _showInAppNotification(message);
      });

      // Handle notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        Log.i('WebNotificationService', 'Notification tapped');
        _handleNotificationTap(message);
      });
    } catch (e) {
      Log.e('WebNotificationService', 'Failed to initialize notifications: $e');
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore.collection('vendor_fcm_tokens').doc(user.uid).set({
        'vendorId': user.uid,
        'token': token,
        'platform': 'web',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUsed': FieldValue.serverTimestamp(),
        'isActive': true,
      }, const SetOptions(merge: true));

      Log.i('WebNotificationService', 'Token saved for vendor: ${user.uid}');
    } catch (e) {
      Log.e('WebNotificationService', 'Failed to save token: $e');
    }
  }

  /// Show in-app notification when app is in foreground
  void _showInAppNotification(RemoteMessage message) {
    // The StreamBuilder in VendorNotificationsScreen will auto-update
    // No need for additional handling here
    Log.i('WebNotificationService', 'In-app notification received');
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    Log.i('WebNotificationService', 'Notification tap: ${message.data}');
    // Can navigate to specific order if needed
  }

  /// Remove token on logout
  Future<void> removeToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore.collection('vendor_fcm_tokens').doc(user.uid).update({
        'isActive': false,
        'lastUsed': FieldValue.serverTimestamp(),
      });

      await _messaging.deleteToken();
      Log.i('WebNotificationService', 'Token removed');
    } catch (e) {
      Log.e('WebNotificationService', 'Failed to remove token: $e');
    }
  }
}
