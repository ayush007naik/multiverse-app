import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/delivery_fee_calculator.dart';
import 'wallet_service.dart';

class DeliveryAssignmentService {
  DeliveryAssignmentService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  static const double platformCommissionRate = 0.10;

  final FirebaseFirestore _db;
  late final WalletService _walletService = WalletService(firestore: _db);

  Future<String> createOrderWithAssignment(
    Map<String, dynamic> orderData,
  ) async {
    final deliveryType = DeliveryFeeCalculator.normalizeDeliveryType(
      orderData['deliveryType'] as String?,
    );
    final vehicle = DeliveryFeeCalculator.vehicleForDeliveryType(deliveryType);
    final subtotal = _readDouble(orderData['subtotal'] ?? orderData['total']);
    final deliveryFee = _readDouble(orderData['deliveryFee']);
    final platformCommission = subtotal * platformCommissionRate;
    final vendorEarning = subtotal - platformCommission;
    final deliveryEarning = deliveryFee;
    final vendorWalletId =
        (orderData['vendorId'] as String?) ?? (orderData['shopId'] as String?);

    final partner = await findNearestPartner(
      vehicle: vehicle,
      pickupLat: _readDouble(orderData['shopLat'], fallback: 31.5891),
      pickupLng: _readDouble(orderData['shopLng'], fallback: 76.9124),
    );

    final enrichedOrder = {
      ...orderData,
      'deliveryType': deliveryType,
      'vehicle': vehicle,
      'commissionRate': platformCommissionRate,
      'platformCommission': platformCommission,
      'vendorEarning': vendorEarning,
      'deliveryEarning': deliveryEarning,
      'platformEarning': platformCommission,
      'riderId': partner?['riderId'],
      'riderName': partner?['name'] ?? partner?['riderName'],
      'riderPhone': partner?['phone'],
      'assignmentStatus': partner == null ? 'unassigned' : 'assigned',
      'assignedAt': partner == null ? null : FieldValue.serverTimestamp(),
      'status': orderData['status'] ?? 'placed',
      'earningsCredited': false, // Track if earnings have been credited
      'createdAt': orderData['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final ref = await _db.collection('orders').add(enrichedOrder);

    if (partner != null) {
      await _db.collection('delivery_locations').doc(partner['riderId']).set({
        'assignedOrderId': ref.id,
        'isAvailable': false,
        'lastAssignedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      // If no partner found immediately, mark for background assignment or alert
      // In a real system, you might have a queue or a polling mechanism
      print('No delivery partner available for order ${ref.id}');
    }

    return ref.id;
  }

  Future<Map<String, dynamic>?> findNearestPartner({
    required String vehicle,
    required double pickupLat,
    required double pickupLng,
  }) async {
    final normalizedVehicle = _normalizeVehicle(vehicle);
    QuerySnapshot<Map<String, dynamic>> snapshot = await _db
        .collection('delivery_locations')
        .where('vehicle', isEqualTo: normalizedVehicle)
        .where('isAvailable', isEqualTo: true)
        .get();

    if (snapshot.docs.isEmpty) {
      snapshot = await _db
          .collection('delivery_locations')
          .where('vehicle', isEqualTo: normalizedVehicle)
          .get();
    }

    Map<String, dynamic>? nearest;
    double? nearestDistance;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final lat = _readNullableDouble(data['lat']);
      final lng = _readNullableDouble(data['lng']);
      if (lat == null || lng == null) continue;

      final distance = DeliveryFeeCalculator.calculateDistance(
        userLat: lat,
        userLng: lng,
        shopLat: pickupLat,
        shopLng: pickupLng,
      );

      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance;
        nearest = {
          ...data,
          'riderId': data['riderId'] ?? doc.id,
          'distanceFromPickupKm': distance,
        };
      }
    }

    return nearest;
  }

  /// Credit earnings after successful delivery
  Future<void> creditEarningsOnDelivery(String orderId) async {
    final orderDoc = await _db.collection('orders').doc(orderId).get();
    if (!orderDoc.exists) return;

    final orderData = orderDoc.data()!;
    final earningsCredited = orderData['earningsCredited'] as bool? ?? false;
    
    // Don't credit twice
    if (earningsCredited) return;

    final vendorWalletId =
        (orderData['vendorId'] as String?) ?? (orderData['shopId'] as String?);
    final riderId = orderData['riderId'] as String?;
    final vendorEarning = (orderData['vendorEarning'] as num?)?.toDouble() ?? 0;
    final deliveryEarning = (orderData['deliveryEarning'] as num?)?.toDouble() ?? 0;
    final platformCommission = (orderData['platformCommission'] as num?)?.toDouble() ?? 0;

    await _updateEarningStats(
      shopId: orderData['shopId'] as String?,
      vendorWalletId: vendorWalletId,
      riderId: riderId,
      vendorEarning: vendorEarning,
      deliveryEarning: deliveryEarning,
      platformCommission: platformCommission,
    );

    // Mark earnings as credited
    await _db.collection('orders').doc(orderId).update({
      'earningsCredited': true,
      'earningsCreditedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateEarningStats({
    required String? shopId,
    required String? vendorWalletId,
    required String? riderId,
    required double vendorEarning,
    required double deliveryEarning,
    required double platformCommission,
  }) async {
    if (shopId != null && shopId.isNotEmpty) {
      await _db.collection('vendor_earnings').doc(shopId).set({
        'totalEarning': FieldValue.increment(vendorEarning),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (vendorWalletId != null && vendorWalletId.isNotEmpty) {
      await _walletService.credit(
        userId: vendorWalletId,
        ownerType: 'vendor',
        amount: vendorEarning,
        source: 'order_vendor_earning',
        description: 'Vendor earning credited',
        metadata: {'shopId': shopId},
      );
    }

    if (riderId != null && riderId.isNotEmpty) {
      await _db.collection('delivery_earnings').doc(riderId).set({
        'totalEarning': FieldValue.increment(deliveryEarning),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _walletService.credit(
        userId: riderId,
        ownerType: 'delivery_partner',
        amount: deliveryEarning,
        source: 'order_delivery_earning',
        description: 'Delivery earning credited',
        metadata: {'shopId': shopId},
      );
    }

    await _db.collection('platform_stats').doc('earnings').set({
      'totalCommission': FieldValue.increment(platformCommission),
      'commissionRate': platformCommissionRate,
      'totalOrders': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _walletService.credit(
      userId: 'platform',
      ownerType: 'platform',
      amount: platformCommission,
      source: 'platform_commission',
      description: 'Platform commission credited',
      metadata: {'shopId': shopId},
    );
  }

  String _normalizeVehicle(String vehicle) {
    final value = vehicle.toLowerCase().trim();
    if (value == DeliveryFeeCalculator.carVehicle ||
        value == 'four-wheeler' ||
        value == 'four_wheeler' ||
        value == '4-wheeler' ||
        value == 'car' ||
        value == 'van') {
      return DeliveryFeeCalculator.carVehicle;
    }
    return DeliveryFeeCalculator.bikeVehicle;
  }

  double _readDouble(dynamic value, {double fallback = 0}) {
    return _readNullableDouble(value) ?? fallback;
  }

  double? _readNullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// New method to assign a partner to an existing order
  Future<void> findAndAssignPartner(String orderId) async {
    final orderDoc = await _db.collection('orders').doc(orderId).get();
    if (!orderDoc.exists) return;

    final orderData = orderDoc.data()!;
    if (orderData['riderId'] != null) return; // Already assigned

    final vehicle = orderData['vehicle'] as String? ?? 'bike';
    final shopLat = _readDouble(orderData['shopLat'], fallback: 31.5891);
    final shopLng = _readDouble(orderData['shopLng'], fallback: 76.9124);

    final partner = await findNearestPartner(
      vehicle: vehicle,
      pickupLat: shopLat,
      pickupLng: shopLng,
    );

    if (partner != null) {
      await _db.collection('orders').doc(orderId).update({
        'riderId': partner['riderId'],
        'riderName': partner['name'] ?? partner['riderName'],
        'riderPhone': partner['phone'],
        'assignmentStatus': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('delivery_locations').doc(partner['riderId']).set({
        'assignedOrderId': orderId,
        'isAvailable': false,
        'lastAssignedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
