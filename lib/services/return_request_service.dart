import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../core/logging_service.dart';

class ReturnRequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _generateOTP() {
    return (1000 + Random().nextInt(9000)).toString();
  }

  // Create return request
  static Future<String> createReturnRequest({
    required String orderId,
    required String requestType, // always 'return'
    required String reason,
    required List<String> issueType, // ['wrong_item', 'broken_item']
    List<String>? images, // List of image URLs
    String? upiId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get order details
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) throw Exception('Order not found');

      final orderData = orderDoc.data()!;
      final deliveredAt = orderData['deliveredAt'] as Timestamp?;

      // Check if within 1 hour
      if (deliveredAt != null) {
        final deliveredTime = deliveredAt.toDate();
        final now = DateTime.now();
        final difference = now.difference(deliveredTime);
        if (difference.inHours >= 1) {
          throw Exception('Return window expired (1 hour after delivery)');
        }
      }

      // Generate OTP for pickup verification
      final pickupOtp = _generateOTP();

      // Create return request
      final docRef = await _firestore.collection('return_requests').add({
        'orderId': orderId,
        'userId': user.uid,
        'customerId': user.uid, // Added for rule consistency
        'shopId': orderData['shopId'] ?? '',
        'vendorId': orderData['vendorId'] ?? '',
        'requestType': requestType,
        'reason': reason,
        'issueType': issueType,
        'images': images ?? [],
        'upiId': upiId,
        'status': 'pending',
        'adminStatus': 'pending',
        'vendorNotified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'otp': pickupOtp, // Store OTP for verification
        'pickupOtp': pickupOtp, // Fallback key
        // Order details
        // orderAmount = customer refund (total - deliveryFee = item value + GST)
        'orderAmount':
            ((orderData['total'] ?? 0).toDouble() -
            (orderData['deliveryFee'] ?? 0).toDouble()),
        'customerName': orderData['customerName'] ?? '',
        'customerEmail': user.email ?? '',
        'customerPhone': orderData['customerPhone'] ?? '',
        'shopName': orderData['shopName'] ?? '',
        'vendorName': orderData['vendorName'] ?? '',
        'deliveryAddress': orderData['deliveryAddress'] ?? {},
        'deliveryBoyId': orderData['deliveryBoyId'] ?? '',
        'deliveryRate':
            orderData['deliveryFee'] ?? orderData['deliveryCharge'] ?? 0,

        // Customer coordinates (extracted for easy querying by delivery partners)
        'customerLat':
            orderData['customerLat'] ??
            orderData['customerLatitude'] ??
            (orderData['deliveryAddress'] is Map
                ? (orderData['deliveryAddress']['latitude'] ??
                      orderData['deliveryAddress']['lat'] ??
                      0)
                : 0),
        'customerLng':
            orderData['customerLng'] ??
            orderData['customerLongitude'] ??
            (orderData['deliveryAddress'] is Map
                ? (orderData['deliveryAddress']['longitude'] ??
                      orderData['deliveryAddress']['lng'] ??
                      0)
                : 0),

        // Pickup details
        'pickupScheduled': false,
        'pickupBoyId': '',
        'pickupStatus':
            'not_scheduled', // not_scheduled, scheduled, in_transit, completed
        'pickupScheduledAt': null,
        'pickupCompletedAt': null,

        // Refund details
        'refundStatus': 'not_initiated', // not_initiated, processing, completed
        'refundAmount': 0,
        'refundCompletedAt': null,
      });

      return docRef.id;
    } catch (e) {
      Log.e('ReturnRequestService', 'Error creating return request: $e', ex: e);
      rethrow;
    }
  }

  // Check if return is available (within 1 hour)
  static Future<Map<String, dynamic>> checkReturnAvailability(
    String orderId,
  ) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        return {'available': false, 'reason': 'Order not found'};
      }

      final orderData = orderDoc.data()!;
      final status = orderData['status'] ?? '';

      if (status != 'delivered') {
        return {'available': false, 'reason': 'Order not delivered yet'};
      }

      // Check if already requested
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'available': false, 'reason': 'User not authenticated'};
      }

      final existingRequest = await _firestore
          .collection('return_requests')
          .where('orderId', isEqualTo: orderId)
          .where('userId', isEqualTo: user.uid) // Rule compliance
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        return {'available': false, 'reason': 'Return already requested'};
      }

      // Check 1 hour window
      final deliveredAt = orderData['deliveredAt'] as Timestamp?;
      if (deliveredAt == null) {
        return {'available': false, 'reason': 'Delivery time not recorded'};
      }

      final deliveredTime = deliveredAt.toDate();
      final now = DateTime.now();
      final difference = now.difference(deliveredTime);

      if (difference.inHours >= 1) {
        return {
          'available': false,
          'reason': 'Return window expired',
          'deliveredAt': deliveredTime,
          'timeRemaining': 0,
        };
      }

      final timeRemaining = const Duration(hours: 1) - difference;

      return {
        'available': true,
        'reason': '',
        'deliveredAt': deliveredTime,
        'timeRemaining': timeRemaining.inMinutes,
      };
    } catch (e) {
      return {'available': false, 'reason': 'Error: $e'};
    }
  }

  // Admin approve/reject return request
  static Future<void> adminUpdateStatus(
    String requestId,
    String adminStatus, {
    String? rejectionReason,
  }) async {
    try {
      final updateData = {
        'adminStatus': adminStatus,
        'adminUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (adminStatus == 'approved') {
        updateData['status'] = 'admin_approved';
        updateData['vendorNotified'] = true;
      } else if (adminStatus == 'rejected') {
        updateData['status'] = 'admin_rejected';
        updateData['rejectionReason'] = rejectionReason ?? '';
      }

      await _firestore
          .collection('return_requests')
          .doc(requestId)
          .update(updateData);
    } catch (e) {
      Log.e('ReturnRequestService', 'Error updating return request: $e', ex: e);
      rethrow;
    }
  }

  // Schedule pickup with delivery boy
  static Future<void> schedulePickup(
    String requestId,
    String deliveryBoyId,
  ) async {
    try {
      await _firestore.collection('return_requests').doc(requestId).update({
        'pickupScheduled': true,
        'pickupBoyId': deliveryBoyId,
        'pickupStatus': 'scheduled',
        'pickupScheduledAt': FieldValue.serverTimestamp(),
        'status': 'pickup_scheduled',
      });
    } catch (e) {
      Log.e('ReturnRequestService', 'Error scheduling pickup: $e', ex: e);
      rethrow;
    }
  }

  // Update pickup status
  static Future<void> updatePickupStatus(
    String requestId,
    String pickupStatus,
  ) async {
    try {
      final Map<String, dynamic> updateData = {'pickupStatus': pickupStatus};

      if (pickupStatus == 'completed') {
        updateData['pickupCompletedAt'] = FieldValue.serverTimestamp();
        updateData['status'] = 'pickup_completed';
      } else if (pickupStatus == 'in_transit') {
        updateData['status'] = 'pickup_in_transit';
      }

      await _firestore
          .collection('return_requests')
          .doc(requestId)
          .update(updateData);
    } catch (e) {
      Log.e('ReturnRequestService', 'Error updating pickup status: $e', ex: e);
      rethrow;
    }
  }

  // Process refund
  static Future<void> processRefund(
    String requestId,
    double refundAmount,
  ) async {
    try {
      await _firestore.collection('return_requests').doc(requestId).update({
        'refundStatus': 'completed',
        'refundAmount': refundAmount,
        'refundCompletedAt': FieldValue.serverTimestamp(),
        'status': 'refund_processed',
      });
    } catch (e) {
      Log.e('ReturnRequestService', 'Error processing refund: $e', ex: e);
      rethrow;
    }
  }

  // Stream for customer to track return request
  static Stream<DocumentSnapshot> getReturnRequestStream(String orderId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return _firestore
        .collection('return_requests')
        .where('orderId', isEqualTo: orderId)
        .where('userId', isEqualTo: user.uid) // Rule compliance
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            throw Exception('No return request found');
          }
          return snapshot.docs.first;
        });
  }

  // Get all return requests for admin
  static Stream<QuerySnapshot> getAdminReturnRequests() {
    return _firestore
        .collection('return_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get return requests for vendor (read-only)
  static Stream<QuerySnapshot> getVendorReturnRequests(String vendorId) {
    return _firestore
        .collection('return_requests')
        .where('vendorId', isEqualTo: vendorId)
        .where('adminStatus', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get pickup requests for delivery boy
  static Stream<QuerySnapshot> getPickupRequests(String deliveryBoyId) {
    return _firestore
        .collection('return_requests')
        .where('pickupBoyId', isEqualTo: deliveryBoyId)
        .orderBy('pickupScheduledAt', descending: true)
        .snapshots();
  }
}
