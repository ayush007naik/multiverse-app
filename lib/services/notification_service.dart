import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart';

/// Notification service for handling push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize notifications and request permissions
  Future<void> initialize() async {
    // Request permission for iOS
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');

    // Get FCM token
    await getAndSaveToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      _saveTokenToFirestore(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

    // Handle notification tap when app is terminated
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleTerminatedMessageTap(initialMessage);
    }
  }

  /// Get FCM token and save to Firestore
  Future<String?> getAndSaveToken() async {
    try {
      String? token;
      
      if (Platform.isIOS) {
        token = await _messaging.getAPNSToken();
      }
      
      token = await _messaging.getToken();
      
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _saveTokenToFirestore(token);
      }
      
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Save to user document
    await _db.collection('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // If user is a delivery partner, also save to delivery_locations
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'] as String?;
    
    if (role == 'Delivery') {
      await _db.collection('delivery_locations').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Remove FCM token on logout
  Future<void> removeToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await _db.collection('users').doc(user.uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.notification?.title}');
    
    // Show local notification
    if (message.notification != null) {
      _showLocalNotification(message);
    }
  }

  /// Handle background message tap
  void _handleBackgroundMessageTap(RemoteMessage message) {
    debugPrint('Notification tapped (background): ${message.data}');
    _navigateFromNotification(message.data);
  }

  /// Handle terminated message tap
  void _handleTerminatedMessageTap(RemoteMessage message) {
    debugPrint('Notification tapped (terminated): ${message.data}');
    _navigateFromNotification(message.data);
  }

  /// Show local notification for foreground messages
  void _showLocalNotification(RemoteMessage message) {
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';
    
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body),
          ],
        ),
        backgroundColor: const Color(0xFFFF4D4F),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            // Handle view action
          },
        ),
      ),
    );
  }

  /// Navigate based on notification data
  void _navigateFromNotification(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final orderId = data['orderId'] as String?;

    if (orderId != null) {
      // Navigate to order tracking or details
      // This will be handled by the app's navigation system
      debugPrint('Navigate to order: $orderId');
    }
  }

  /// Send notification to user (for cloud functions or admin use)
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // This is typically done via Firebase Cloud Functions
    // But you can also use Firebase Admin SDK from your backend
    debugPrint('Send notification to user $userId: $title');
    
    // For now, we'll log it. In production, call your backend API
    // or use Firebase Cloud Functions to send the notification
  }

  /// Send notification to topic (for broadcast messages)
  Future<void> sendNotificationToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    debugPrint('Send notification to topic $topic: $title');
    // Similar to above, this should be done via Cloud Functions
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }
}

/// Helper class for notification payloads
class NotificationPayload {
  final String type;
  final String orderId;
  final String title;
  final String message;
  final Map<String, dynamic> data;

  NotificationPayload({
    required this.type,
    required this.orderId,
    required this.title,
    required this.message,
    required this.data,
  });

  factory NotificationPayload.fromMap(Map<String, dynamic> map) {
    return NotificationPayload(
      type: map['type'] ?? 'general',
      orderId: map['orderId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      data: map,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'orderId': orderId,
      'title': title,
      'message': message,
      ...data,
    };
  }
}
