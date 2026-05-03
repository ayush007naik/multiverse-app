import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/delivery_fee_calculator.dart';

class ShopService {
  ShopService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _shops =>
      _firestore.collection('shops');

  Future<String> createShop({
    required String ownerId,
    required String name,
    required String category,
    required String imageUrl,
    required String locationLabel,
    required double latitude,
    required double longitude,
    String city = '',
    String area = '',
    bool isActive = true,
  }) async {
    final doc = _shops.doc();
    final normalizedName = name.trim();
    final normalizedCategory = category.trim();
    final normalizedCity = city.trim();
    final normalizedArea = area.trim();
    final normalizedLocationLabel = locationLabel.trim();

    final shopData = {
      'ownerId': ownerId,
      'name': normalizedName,
      'category': normalizedCategory,
      'image': imageUrl.trim(),
      'locationLabel': normalizedLocationLabel,
      'city': normalizedCity,
      'area': normalizedArea,
      'lat': latitude,
      'lng': longitude,
      'location': {
        'label': normalizedLocationLabel,
        'city': normalizedCity,
        'area': normalizedArea,
        'latitude': latitude,
        'longitude': longitude,
      },
      'rating': 0.0,
      'eta': '20-30 min',
      'icon': _iconForCategory(normalizedCategory),
      'color': _colorForCategory(normalizedCategory),
      'open': isActive,
      'isActive': isActive,
      'isApproved': true,
      'searchKeywords': _buildSearchKeywords(
        normalizedName,
        normalizedCategory,
        normalizedCity,
        normalizedArea,
      ),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await doc.set(shopData);
    return doc.id;
  }

  Stream<List<Map<String, dynamic>>> streamActiveShops() {
    return _shops
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(_mapShopSnapshot);
  }

  Stream<List<Map<String, dynamic>>> streamVendorShops(String ownerId) {
    return _shops
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(_mapShopSnapshot);
  }

  List<Map<String, dynamic>> _mapShopSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final shops = snapshot.docs
        .map((doc) => normalizeShopData(doc.data(), doc.id))
        .toList();
    shops.sort((a, b) {
      final aUpdatedAt = a['updatedAt'];
      final bUpdatedAt = b['updatedAt'];
      if (aUpdatedAt is Timestamp && bUpdatedAt is Timestamp) {
        return bUpdatedAt.compareTo(aUpdatedAt);
      }
      return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
    });
    return shops;
  }

  static Map<String, dynamic> normalizeShopData(
    Map<String, dynamic> data,
    String id,
  ) {
    return {
      ...data,
      'id': id,
      'locationLabel': locationLabelFromData(data),
      'lat': readCoordinate(data, const ['lat', 'latitude']),
      'lng': readCoordinate(data, const ['lng', 'longitude']),
      'isActive': data['isActive'] ?? data['open'] ?? true,
      'open': data['open'] ?? data['isActive'] ?? true,
      'isApproved': true,
    };
  }

  static double? readCoordinate(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
    }

    final location = data['location'];
    if (location is Map<String, dynamic>) {
      for (final key in keys) {
        final value = location[key];
        if (value is num) return value.toDouble();
      }

      if (keys.contains('lat') || keys.contains('latitude')) {
        final value = location['latitude'];
        if (value is num) return value.toDouble();
      }

      if (keys.contains('lng') || keys.contains('longitude')) {
        final value = location['longitude'];
        if (value is num) return value.toDouble();
      }
    }

    return null;
  }

  static String locationLabelFromData(Map<String, dynamic> data) {
    final directLabel = data['locationLabel'] as String?;
    if (directLabel != null && directLabel.trim().isNotEmpty) {
      return directLabel.trim();
    }

    final location = data['location'];
    if (location is Map<String, dynamic>) {
      final label = location['label'] as String?;
      if (label != null && label.trim().isNotEmpty) {
        return label.trim();
      }
      final area = location['area'] as String?;
      final city = location['city'] as String?;
      final parts = [area, city]
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) return parts.join(', ');
    }

    final parts = [data['area'] as String?, data['city'] as String?]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    return parts.isNotEmpty ? parts.join(', ') : 'Location unavailable';
  }

  static double? distanceKmForShop(
    Map<String, dynamic> shop, {
    required double userLat,
    required double userLng,
  }) {
    final shopLat = readCoordinate(shop, const ['lat', 'latitude']);
    final shopLng = readCoordinate(shop, const ['lng', 'longitude']);
    if (shopLat == null || shopLng == null) return null;

    return DeliveryFeeCalculator.calculateDistance(
      userLat: userLat,
      userLng: userLng,
      shopLat: shopLat,
      shopLng: shopLng,
    );
  }

  static List<String> _buildSearchKeywords(
    String name,
    String category,
    String city,
    String area,
  ) {
    final tokens = <String>{};
    for (final raw in [name, category, city, area]) {
      final normalized = raw.toLowerCase().trim();
      if (normalized.isEmpty) continue;
      tokens.add(normalized);
      for (final part in normalized.split(RegExp(r'[\s,]+'))) {
        if (part.isNotEmpty) tokens.add(part);
      }
    }
    return tokens.toList();
  }

  static String _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'grocery':
        return '🛒';
      case 'pharmacy':
        return '💊';
      case 'clothing':
        return '👔';
      case 'food':
      case 'restaurant':
        return '🍽️';
      case 'electronics':
        return '📱';
      case 'hardware':
        return '🔨';
      case 'beauty':
        return '🧴';
      default:
        return '🏪';
    }
  }

  static int _colorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'grocery':
        return 0xFF43A047;
      case 'pharmacy':
        return 0xFF1E88E5;
      case 'clothing':
        return 0xFFD81B60;
      case 'food':
      case 'restaurant':
        return 0xFFF4511E;
      case 'electronics':
        return 0xFF5E35B1;
      case 'hardware':
        return 0xFFFF9800;
      case 'beauty':
        return 0xFF8E24AA;
      default:
        return 0xFFFF4D4F;
    }
  }
}
