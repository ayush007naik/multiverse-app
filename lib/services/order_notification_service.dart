import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Service to handle order-related notifications
class OrderNotificationService {
  static final OrderNotificationService _instance =
      OrderNotificationService._internal();
  factory OrderNotificationService() => _instance;
  OrderNotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Trigger notification when order is placed
  Future<void> notifyOrderPlaced(String orderId) async {
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final vendorId = orderData['vendorId'] as String?;
      final shopName = orderData['shopName'] as String? ?? 'Shop';

      // Notify vendor
      if (vendorId != null) {
        await _saveNotificationToFirestore(
          userId: vendorId,
          title: 'New Order Received! ',
          message: 'You have a new order from $shopName',
          type: 'new_order',
          orderId: orderId,
          data: orderData,
        );
      }

      debugPrint('Order placed notification sent for $orderId');
    } catch (e) {
      debugPrint('Error sending order placed notification: $e');
    }
  }

  /// Trigger notification when vendor accepts order
  Future<void> notifyOrderAccepted(String orderId) async {
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final userId = orderData['userId'] as String?;
      final shopName = orderData['shopName'] as String? ?? 'Shop';

      // Notify customer
      if (userId != null) {
        await _saveNotificationToFirestore(
          userId: userId,
          title: 'Order Accepted! ✅',
          message: 'Your order from $shopName has been accepted',
          type: 'order_accepted',
          orderId: orderId,
          data: orderData,
        );
      }

      debugPrint('Order accepted notification sent for $orderId');
    } catch (e) {
      debugPrint('Error sending order accepted notification: $e');
    }
  }

  /// Trigger notification when order is ready for pickup
  Future<void> notifyOrderReady(String orderId) async {
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final userId = orderData['userId'] as String?;
      final shopName = orderData['shopName'] as String? ?? 'Shop';

      // Notify customer
      if (userId != null) {
        await _saveNotificationToFirestore(
          userId: userId,
          title: 'Order Accepted! ✅',
          message: 'Your order from $shopName has been accepted and is being prepared',
          type: 'order_accepted',
          orderId: orderId,
          data: orderData,
        );
      }

      debugPrint('Order accepted notification sent for $orderId');
    } catch (e) {
      debugPrint('Error sending order accepted notification: $e');
    }
  }

  /// Trigger notification when delivery partner picks up order
  Future<void> notifyOrderPicked(String orderId) async {
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final userId = orderData['userId'] as String?;
      final riderName = orderData['riderName'] as String? ?? 'Delivery Partner';
      final shopName = orderData['shopName'] as String? ?? 'Shop';

      // Notify customer
      if (userId != null) {
        await _saveNotificationToFirestore(
          userId: userId,
          title: 'Order Picked Up! ',
          message: '$riderName picked up your order from $shopName',
          type: 'order_picked',
          orderId: orderId,
          data: orderData,
        );
      }

      debugPrint('Order picked notification sent for $orderId');
    } catch (e) {
      debugPrint('Error sending order picked notification: $e');
    }
  }

  /// Trigger notification when order is delivered
  Future<void> notifyOrderDelivered(String orderId) async {
    try {
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final userId = orderData['userId'] as String?;
      final shopName = orderData['shopName'] as String? ?? 'Shop';
      final totalAmount = orderData['totalAmount'] as num? ?? 0;

      // Notify customer
      if (userId != null) {
        await _saveNotificationToFirestore(
          userId: userId,
          title: 'Order Delivered! ',
          message:
              'Your order from $shopName has been delivered. Amount: ₹${totalAmount.toStringAsFixed(0)}',
          type: 'order_delivered',
          orderId: orderId,
          data: orderData,
        );
      }

      debugPrint('Order delivered notification sent for $orderId');
    } catch (e) {
      debugPrint('Error sending order delivered notification: $e');
    }
  }

  /// Save notification to Firestore for in-app notification center
  Future<void> _saveNotificationToFirestore({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? orderId,
    Map<String, dynamic>? data,
  }) async {
    await _db.collection('notifications').add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      if (orderId != null) 'orderId': orderId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'data': data ?? {},
    });
  }

  /// Admin: Send notification to a specific user
  Future<void> sendAdminNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    await _saveNotificationToFirestore(
      userId: userId,
      title: title,
      message: message,
      type: 'admin_message',
    );
  }

  /// Admin: Broadcast to a specific role or all users
  Future<void> broadcastNotification({
    required String title,
    required String message,
    String? role, // 'Customer', 'Vendor', etc. null for all
  }) async {
    Query query = _db.collection('users');
    if (role != null) {
      query = query.where('role', isEqualTo: role);
    }

    final usersSnapshot = await query.get();
    final batch = _db.batch();

    for (var userDoc in usersSnapshot.docs) {
      final notifRef = _db.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': userDoc.id,
        'title': title,
        'message': message,
        'type': 'admin_broadcast',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Get unread notification count for user
  Stream<int> getUnreadNotificationCount(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    await _db
        .collection('notifications')
        .doc(notificationId)
        .update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Get all notifications for user
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}