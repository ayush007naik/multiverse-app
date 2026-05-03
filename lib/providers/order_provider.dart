import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_model.dart';
import '../services/delivery_assignment_service.dart';

/// Provider for real-time order updates across vendor and delivery modules
class OrderProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream subscriptions are managed by StreamBuilder in UI
  // This provider provides the streams and helper methods

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// STANDARDIZED: Stream orders for a specific shop (vendor view)
  /// Vendor listens to orders where shopId == currentShopId
  /// NO orderBy to avoid composite index errors
  Stream<QuerySnapshot<Map<String, dynamic>>> streamShopOrders(String shopId) {
    if (shopId.isEmpty) {
      debugPrint('⚠️ [OrderProvider] shopId is empty!');
      return Stream.empty();
    }

    debugPrint('🔥 [OrderProvider] Streaming orders for shop: $shopId');

    return _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .snapshots();
  }

  /// Stream pending orders for vendor (status = pending)
  /// NO orderBy to avoid composite index errors
  Stream<QuerySnapshot<Map<String, dynamic>>> streamVendorPendingOrders(String shopId) {
    if (shopId.isEmpty) return Stream.empty();

    return _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: OrderModel.statusPending)
        .snapshots();
  }

  /// Stream active orders for vendor (pending, accepted, preparing, ready)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamVendorActiveOrders(String shopId) {
    if (shopId.isEmpty) return Stream.empty();

    return _firestore
        .collection('orders')
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: [
          OrderModel.statusPending,
          OrderModel.statusAccepted,
          OrderModel.statusPreparing,
          OrderModel.statusReady,
        ])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// STANDARDIZED: Stream ready orders for delivery
  /// Delivery listens to orders where status == "ready"
  /// FIXED: Removed orderBy to avoid composite index errors
  Stream<QuerySnapshot<Map<String, dynamic>>> streamPendingDeliveryOrders() {
    debugPrint('🔥 [OrderProvider] Streaming ready orders for delivery');

    return _firestore
        .collection('orders')
        .where('status', isEqualTo: OrderModel.statusReady)
        .snapshots();
  }

  /// Stream orders assigned to specific rider
  /// FIXED: Removed orderBy to avoid composite index errors
  /// Client-side sorting is safer and doesn't require Firestore indexes
  Stream<QuerySnapshot<Map<String, dynamic>>> streamRiderOrders(String riderId) {
    if (riderId.isEmpty) return Stream.empty();

    debugPrint('🔥 [OrderProvider] Streaming orders for rider: $riderId');

    return _firestore
        .collection('orders')
        .where('riderId', isEqualTo: riderId)
        .where('status', whereIn: [
          OrderModel.statusPicked,
          OrderModel.statusOutOfDelivery,
          OrderModel.statusDelivered
        ])
        .snapshots();
  }

  /// Stream customer orders (real-time)
  /// NO orderBy to avoid composite index errors
  Stream<QuerySnapshot<Map<String, dynamic>>> streamCustomerOrders(String userId) {
    if (userId.isEmpty) return Stream.empty();

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  /// Stream orders for a vendor filtered by multiple statuses
  /// NO orderBy to avoid composite index errors - client-side sorting is safer
  Stream<QuerySnapshot<Map<String, dynamic>>> streamVendorOrdersByStatus(String vendorId, List<String> statuses) {
    if (vendorId.isEmpty) return Stream.empty();

    debugPrint('🔥 [OrderProvider] Streaming orders for vendor: $vendorId with statuses: $statuses');

    return _firestore
        .collection('orders')
        .where('vendorId', isEqualTo: vendorId)
        .where('status', whereIn: statuses)
        .snapshots();
  }

  /// Create new order with complete details and financial breakdown
  Future<String> createOrder({
    required String userId,
    required String shopId,
    String? vendorId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double deliveryFee,
    required double gst,
    required double total,
    Map<String, dynamic>? address,
    String? customerName,
    String? customerPhone,
    double? customerLat,
    double? customerLng,
    String? deliveryType,
    String? vehicle,
    String? paymentMethod,
    String? paymentStatus,
    String? paymentId,
    String? specialRequest,
  }) async {
    debugPrint('📝 [OrderProvider] Creating new order for shopId: $shopId, vendorId: $vendorId, userId: $userId');

    if (shopId.isEmpty) {
      debugPrint('❌ [OrderProvider] Cannot create order: shopId is empty');
      throw Exception('Shop ID is required to create an order');
    }

    // Financial calculations (aligned with InvoiceGeneratorService)
    // Platform Commission: 10%
    const double commissionRate = 0.10;
    final double commissionAmount = subtotal * commissionRate;
    
    // GST on Commission: 18% of commission amount
    final double gstOnCommission = commissionAmount * 0.18;
    
    // Total deductions from vendor subtotal
    final double totalDeductions = commissionAmount + gstOnCommission;
    
    // Net Vendor Earning (Subtotal - Commission - GST on Commission)
    final double vendorEarning = subtotal - totalDeductions;
    
    // Delivery Earning (Full delivery fee goes to rider for now)
    final double deliveryEarning = deliveryFee;

    final orderData = {
      'userId': userId,
      'shopId': shopId,
      'vendorId': vendorId,
      'items': items,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'gst': gst,
      'total': total,
      'status': OrderModel.statusPending,
      'address': address,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'deliveryType': deliveryType ?? 'normal',
      'vehicle': vehicle ?? 'bike',
      'paymentMethod': paymentMethod ?? 'cod',
      'paymentStatus': paymentStatus ?? 'pending',
      'paymentId': paymentId, // Add payment ID from Razorpay
      'specialRequest': specialRequest ?? '', // 👈 Store special request/instructions
      
      // Financial Enrichment
      'commissionRate': commissionRate,
      'platformCommission': commissionAmount,
      'gstOnCommission': gstOnCommission,
      'vendorEarning': vendorEarning,
      'deliveryEarning': deliveryEarning,
      'platformEarning': totalDeductions,
      'earningsCredited': false,
      
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final docRef = await _firestore.collection('orders').add(orderData);
      debugPrint('✅ [OrderProvider] Order created successfully with ID: ${docRef.id}');
      
      // Trigger background delivery assignment
      try {
        await DeliveryAssignmentService().findAndAssignPartner(docRef.id);
      } catch (e) {
        debugPrint('⚠️ [OrderProvider] Background assignment failed: $e');
      }

      return docRef.id;
    } catch (e) {
      debugPrint('❌ [OrderProvider] Failed to create order in Firestore: $e');
      rethrow;
    }
  }

  /// Vendor confirms order → update status = "accepted"
  Future<void> confirmOrder(String orderId) async {
    debugPrint('✅ [OrderProvider] Vendor confirming order: $orderId');

    // Get order to find shopId for debug logging
    final orderDoc = await _firestore.collection('orders').doc(orderId).get();
    if (!orderDoc.exists) {
      debugPrint('❌ [OrderProvider] Order not found: $orderId');
      throw Exception('Order not found');
    }

    final orderData = orderDoc.data()!;
    final shopId = orderData['shopId'] ?? 'unknown';

    debugPrint('📝 [OrderProvider] Updating order $orderId (shopId: $shopId) status to: accepted');

    await _firestore.collection('orders').doc(orderId).update({
      'status': OrderModel.statusAccepted,  // Changed from 'confirmed' to 'accepted'
      'confirmedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ [OrderProvider] Order $orderId confirmed successfully (status: accepted)');
  }

  /// Alias for confirmOrder (for compatibility with code using acceptOrder)
  Future<void> acceptOrder(String orderId) async {
    return confirmOrder(orderId);
  }

  /// Vendor marks order as preparing → status = "preparing"
  Future<void> startPreparingOrder(String orderId) async {
    debugPrint('🍳 [OrderProvider] Vendor preparing order: $orderId');

    await _firestore.collection('orders').doc(orderId).update({
      'status': OrderModel.statusPreparing,
      'preparingStartedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ [OrderProvider] Order preparation started');
  }

  /// Vendor marks order as ready → status = "ready"
  Future<void> markOrderReady(String orderId) async {
    debugPrint('✅ [OrderProvider] Vendor marking order ready: $orderId');

    await _firestore.collection('orders').doc(orderId).update({
      'status': OrderModel.statusReady,
      'readyAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ [OrderProvider] Order marked as ready for pickup');
  }

  /// Delivery partner accepts order → assign and status = "picked"
  Future<void> assignDeliveryPartner(String orderId, String deliveryBoyId) async {
    debugPrint('🚴 [OrderProvider] Assigning delivery partner: $deliveryBoyId');

    await _firestore.collection('orders').doc(orderId).update({
      'riderId': deliveryBoyId,
      'status': OrderModel.statusPicked,
      'assignedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ [OrderProvider] Order assigned to delivery partner');
  }

  /// Rider picks up order → status = "picked"
  Future<void> pickOrder(String orderId, String riderId) async {
    debugPrint('🚴 [OrderProvider] Rider picking up order: $orderId');

    await _firestore.collection('orders').doc(orderId).update({
      'riderId': riderId,
      'status': OrderModel.statusPicked,
      'pickedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ [OrderProvider] Order picked up by rider');
  }

  /// Mark order as delivered
  Future<void> deliverOrder(String orderId) async {
    debugPrint('🎊 [OrderProvider] Delivering order: $orderId');

    await _firestore.collection('orders').doc(orderId).update({
      'status': OrderModel.statusDelivered,
      'deliveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // STANDARDIZED: Trigger earnings credit on delivery
    try {
      await DeliveryAssignmentService().creditEarningsOnDelivery(orderId);
      debugPrint('💰 [OrderProvider] Earnings credited for order: $orderId');
    } catch (e) {
      debugPrint('⚠️ [OrderProvider] Failed to credit earnings: $e');
    }

    debugPrint('✅ [OrderProvider] Order delivered successfully');
  }

  /// Update order status with appropriate timestamps (useful for Admin)
  Future<void> updateOrderStatus(String orderId, String status) async {
    debugPrint('📝 [OrderProvider] Updating order $orderId to status: $status');
    
    final Map<String, dynamic> updates = {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == OrderModel.statusAccepted) {
      updates['confirmedAt'] = FieldValue.serverTimestamp();
    } else if (status == OrderModel.statusPreparing) {
      updates['preparingStartedAt'] = FieldValue.serverTimestamp();
    } else if (status == OrderModel.statusReady) {
      updates['readyAt'] = FieldValue.serverTimestamp();
    } else if (status == OrderModel.statusPicked || status == OrderModel.statusOutOfDelivery) {
      updates['pickedAt'] = FieldValue.serverTimestamp();
    } else if (status == OrderModel.statusDelivered) {
      updates['deliveredAt'] = FieldValue.serverTimestamp();
    }

    await _firestore.collection('orders').doc(orderId).update(updates);
    
    if (status == OrderModel.statusDelivered) {
      try {
        await DeliveryAssignmentService().creditEarningsOnDelivery(orderId);
      } catch (e) {
        debugPrint('⚠️ [OrderProvider] Failed to credit earnings: $e');
      }
    }
  }

  /// Cancel order
  Future<void> cancelOrder(String orderId) async {
    debugPrint('❌ [OrderProvider] Cancelling order: $orderId');

    await _firestore.collection('orders').doc(orderId).update({
      'status': OrderModel.statusCancelled,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ [OrderProvider] Order cancelled successfully');
  }

  /// Get single order (for one-time reads)
  Future<OrderModel?> getOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (doc.exists) {
        return OrderModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('❌ [OrderProvider] Failed to get order: $e');
      return null;
    }
  }

  /// Stream single order (for real-time tracking)
  Stream<OrderModel?> streamOrder(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return OrderModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    });
  }

  /// Filter orders by status (client-side)
  List<OrderModel> filterOrdersByStatus(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String status,
  ) {
    return snapshot.docs
        .map((doc) => OrderModel.fromFirestore(doc.data(), doc.id))
        .where((order) => order.status == status)
        .toList();
  }

  /// Get active orders count for shop
  Future<int> getActiveOrdersCount(String shopId) async {
    if (shopId.isEmpty) return 0;

    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('shopId', isEqualTo: shopId)
          .where('status', whereIn: [
            OrderModel.statusPending,
            OrderModel.statusAccepted,
            OrderModel.statusPreparing,
            OrderModel.statusReady,
            OrderModel.statusOutOfDelivery,
          ])
          .get();

      return snapshot.size;
    } catch (e) {
      debugPrint('❌ [OrderProvider] Failed to get active orders count: $e');
      return 0;
    }
  }

  /// Get today's orders count for shop
  Future<int> getTodayOrdersCount(String shopId) async {
    if (shopId.isEmpty) return 0;

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final snapshot = await _firestore
          .collection('orders')
          .where('shopId', isEqualTo: shopId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();

      return snapshot.size;
    } catch (e) {
      debugPrint('❌ [OrderProvider] Failed to get today orders count: $e');
      return 0;
    }
  }
}
