import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'delivery_assignment_service.dart';
import 'shop_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final ShopService _shopService = ShopService(firestore: _db);

  // 🏪 Save Shop Data
  Future<void> saveShop(Map<String, dynamic> shopData) async {
    try {
      final ownerId = shopData['ownerId'] as String?;
      final name = shopData['name'] as String?;
      final category = shopData['category'] as String?;
      final latitude = ShopService.readCoordinate(shopData, const [
        'lat',
        'latitude',
      ]);
      final longitude = ShopService.readCoordinate(shopData, const [
        'lng',
        'longitude',
      ]);

      if (ownerId == null ||
          name == null ||
          category == null ||
          latitude == null ||
          longitude == null) {
        throw ArgumentError('Missing required shop fields');
      }

      await _shopService.createShop(
        ownerId: ownerId,
        name: name,
        category: category,
        imageUrl: shopData['image'] as String? ?? '',
        locationLabel: ShopService.locationLabelFromData(shopData),
        latitude: latitude,
        longitude: longitude,
        city: shopData['city'] as String? ?? '',
        area: shopData['area'] as String? ?? '',
        isActive: (shopData['isActive'] as bool?) ?? true,
      );
    } catch (e) {
      debugPrint("Error saving shop: $e");
    }
  }

  // 🛍️ Fetch All Shops
  Stream<List<Map<String, dynamic>>> getShops() {
    return _shopService.streamActiveShops();
  }

  // 📦 Save Order
  Future<void> placeOrder(Map<String, dynamic> orderData) async {
    try {
      await DeliveryAssignmentService(
        firestore: _db,
      ).createOrderWithAssignment(orderData);
    } catch (e) {
      debugPrint("Error placing order: $e");
    }
  }

  // 👤 Update User Profile
  Future<void> updateProfile(String uid, Map<String, dynamic> userData) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .set(userData, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating profile: $e");
    }
  }
}
