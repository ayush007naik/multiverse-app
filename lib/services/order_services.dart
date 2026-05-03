// 📁 lib/services/order_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import 'delivery_assignment_service.dart';
import 'order_notification_service.dart';

class OrderService {
  final _db = FirebaseFirestore.instance;
  final _notificationService = OrderNotificationService();

  // 📝 Place new order with commission logic
  Future<String> placeOrder(Map<String, dynamic> orderData) async {
    final orderId = await DeliveryAssignmentService(
      firestore: _db,
    ).createOrderWithAssignment(orderData);

    // Notify vendor
    await _notificationService.notifyOrderPlaced(orderId);

    return orderId;
  }

  // 📦 Get orders for a shop (real-time)
  Stream<QuerySnapshot> getShopOrders(String shopId) {
    return _db
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: ['new', 'preparing', 'ready'])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 🔄 Update order status
  Future<void> updateStatus(String orderId, String status) async {
    await _db.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Trigger relevant notifications based on status
    switch (status) {
      case 'accepted':
      case 'preparing':
        await _notificationService.notifyOrderAccepted(orderId);
        break;
      case 'ready':
        await _notificationService.notifyOrderReady(orderId);
        break;
      case 'picked':
      case 'shipped':
        await _notificationService.notifyOrderPicked(orderId);
        break;
      case 'delivered':
        await _notificationService.notifyOrderDelivered(orderId);
        break;
    }
  }

  // 📍 Update delivery boy location
  Future<void> updateLocation(String uid, double lat, double lng) async {
    await _db.collection('delivery_boys').doc(uid).update({
      'currentLat': lat,
      'currentLng': lng,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
