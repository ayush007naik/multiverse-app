// 📁 lib/services/movie_notification_service.dart
// Movie notification and FCM push notification service

import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'deep_link_handler.dart';
import 'notification_service.dart';
import '../core/logging_service.dart';

class MovieNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Register user for movie notification (NOTIFY ME button)
  static Future<void> registerForNotification({
    required String movieId,
    required String movieTitle,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Save notification request
      await _firestore.collection('movie_notifications').add({
        'userId': user.uid,
        'movieId': movieId,
        'movieName': movieTitle, // Added as per requirements
        'movieTitle': movieTitle,
        'userEmail': user.email ?? '',
        'userPhone': user.phoneNumber ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'isNotified': true, // Added as per requirements
        'notificationSent': false,
        'status': 'pending',
      });

      Log.i(
        'MovieNotificationService',
        'Registered for notification: $movieTitle',
      );
    } catch (e) {
      Log.e(
        'MovieNotificationService',
        'Error registering for notification: $e',
        ex: e,
      );
      rethrow;
    }
  }

  /// Check if user already registered for movie notification
  static Future<bool> isRegisteredForNotification({
    required String movieId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final snapshot = await _firestore
          .collection('movie_notifications')
          .where('userId', isEqualTo: user.uid)
          .where('movieId', isEqualTo: movieId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      Log.e(
        'MovieNotificationService',
        'Error checking notification status: $e',
        ex: e,
      );
      return false;
    }
  }

  /// Send push notifications when movie becomes available
  static Future<void> sendMovieReleaseNotifications({
    required String movieId,
    required String movieTitle,
  }) async {
    try {
      // Get all users waiting for this movie
      final snapshot = await _firestore
          .collection('movie_notifications')
          .where('movieId', isEqualTo: movieId)
          .where('notificationSent', isEqualTo: false)
          .get();

      List<String> fcmTokens = [];

      for (var doc in snapshot.docs) {
        final userId = doc.data()['userId'] as String;

        // Get user's FCM token
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final fcmToken = userDoc.data()?['fcmToken'] as String?;

        if (fcmToken != null) {
          fcmTokens.add(fcmToken);

          // Mark notification as sent
          await doc.reference.update({
            'notificationSent': true,
            'sentAt': FieldValue.serverTimestamp(),
            'status': 'sent',
          });
        }
      }

      // Send push notifications
      for (String token in fcmTokens) {
        await _sendPushNotification(
          token: token,
          title: '🎬 Now Showing!',
          body: '$movieTitle is now showing near you! Book your tickets now.',
          data: {
            'movieId': movieId,
            'type': 'movie_release',
            'screen': 'movie_booking',
          },
        );
      }

      Log.i(
        'MovieNotificationService',
        'Sent notifications to ${fcmTokens.length} users for $movieTitle',
      );
    } catch (e) {
      Log.e(
        'MovieNotificationService',
        'Error sending notifications: $e',
        ex: e,
      );
      rethrow;
    }
  }

  /// Send push notification to a specific FCM token
  static Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    // Note: This requires a backend Cloud Function or server
    // For now, we'll store the notification request in Firebase
    // A Cloud Function should handle actual FCM delivery

    await _firestore.collection('fcm_notifications').add({
      'token': token,
      'title': title,
      'body': body,
      'data': data,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  /// Get FCM token and save to user profile
  static Future<void> saveFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String? token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, const SetOptions(merge: true));

        Log.i('MovieNotificationService', 'FCM token saved');
      }
    } catch (e) {
      Log.e('MovieNotificationService', 'Error saving FCM token: $e', ex: e);
    }
  }

  /// Listen for incoming FCM messages when app is in foreground
  static void setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Log.i(
        'MovieNotificationService',
        'Foreground push: ${message.notification?.title}',
      );
      Log.i('MovieNotificationService', 'Message data: ${message.data}');

      if (message.notification != null) {
        NotificationService().showLocalNotification(message);
      }
    });
  }

  /// Handle notification when user taps on it
  static void setupNotificationTapHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Log.i('MovieNotificationService', 'Notification tapped!');
      Log.i('MovieNotificationService', 'Data: ${message.data}');
      final payload = DeepLinkHandler.parse(message.data);
      DeepLinkHandler.navigate(payload);
    });
  }

  /// Get user's notification history
  static Future<List<Map<String, dynamic>>> getUserNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('movie_notifications')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      Log.e(
        'MovieNotificationService',
        'Error fetching notifications: $e',
        ex: e,
      );
      return [];
    }
  }
}
