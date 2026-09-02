import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/logging_service.dart';
import '../models/provider_model.dart';

/// Real-Time Service Provider Service
/// Connects to Firebase Firestore for LIVE provider data
/// NO dummy/fake/static content
class ServiceProviderService {
  static final ServiceProviderService _instance =
      ServiceProviderService._internal();
  factory ServiceProviderService() => _instance;
  ServiceProviderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _providers => _firestore.collection('providers');
  CollectionReference get _serviceBookings =>
      _firestore.collection('service_bookings');
  CollectionReference get _providerOffers =>
      _firestore.collection('provider_offers');
  CollectionReference get _partners => _firestore.collection('partners');

  // ========== PARTNERS FROM APPOINTMENT DASHBOARD ==========

  /// Get partners from the 'partners' collection by category
  Stream<List<Map<String, dynamic>>> getPartnersByCategory(String category) {
    // Map plural categories from UI to singular stored in Firestore
    String dbCategory = category;
    if (category == 'Doctors') {
      dbCategory = 'Doctor';
    } else if (category == 'Dentists')
      dbCategory = 'Dentist';
    else if (category == 'Salons')
      dbCategory = 'Salon';
    else if (category == 'Diagnostic Labs')
      dbCategory = 'Diagnostic Lab';
    else if (category == 'Car Services')
      dbCategory = 'Car Service';

    return _partners
        .where('category', isEqualTo: dbCategory)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  // ========== SERVICE CATEGORIES ==========

  /// Get all service categories from Firestore
  /// Falls back to default categories if none exist
  Stream<List<Map<String, dynamic>>> getServiceCategories() {
    return _firestore
        .collection('service_categories')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return _getDefaultCategories();
          }

          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'image': data['image'] ?? '',
              'neonColor': Color(data['neonColor'] ?? 0xFFFF7A1A),
              'icon': _getIconData(data['iconCode']),
              'description': data['description'] ?? '',
            };
          }).toList();
        });
  }

  /// Map icon codes to constant IconData to allow tree shaking
  IconData _getIconData(dynamic iconCode) {
    if (iconCode == null) return Icons.category_rounded;

    // Use a switch with constants for known icon codes
    // This satisfies the Flutter compiler for tree shaking
    switch (iconCode) {
      case 0xef2c:
        return Icons.face_retouching_natural;
      case 0xf006c:
        return Icons.plumbing_rounded;
      case 0xf592:
        return Icons.bolt_rounded;
      case 0xf639:
        return Icons.cleaning_services_rounded;
      case 0xeb3b:
        return Icons.ac_unit_rounded;
      case 0xf071:
        return Icons.format_paint_rounded;
      case 0xe0b9:
        return Icons.category_rounded;
      default:
        // If it's a code we don't have mapped, return a default
        // To support COMPLETELY dynamic icons, you'd need to build with --no-tree-shake-icons
        return Icons.category_rounded;
    }
  }

  List<Map<String, dynamic>> _getDefaultCategories() {
    return [];
  }

  // ========== REAL-TIME PROVIDERS ==========

  Stream<List<ProviderModel>> getAvailableProviders(String serviceCategory) {
    return _providers
        .where('serviceCategories', arrayContains: serviceCategory)
        .where('isAvailable', isEqualTo: true)
        .where('isVerified', isEqualTo: true)
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          Log.i('ServiceProviderService', 'Found ${snapshot.docs.length} providers for $serviceCategory');
          final providers = snapshot.docs
              .map((doc) => ProviderModel.fromFirestore(doc))
              .toList();
          providers.sort((a, b) => b.rating.compareTo(a.rating));
          return providers;
        });
  }

  Stream<List<Map<String, dynamic>>> getNearbyProviders({
    required String serviceCategory,
    required double latitude,
    required double longitude,
    double radiusInKm = 10.0,
  }) {
    return getAvailableProviders(serviceCategory).map((providers) {
      final nearbyProviders = <Map<String, dynamic>>[];
      for (final provider in providers) {
        if (provider.location == null) continue;
        final distance = _calculateDistance(
          latitude,
          longitude,
          provider.location!['latitude'],
          provider.location!['longitude'],
        );
        if (distance <= radiusInKm) {
          nearbyProviders.add({
            'provider': provider,
            'distance': distance,
            'eta': _calculateETA(distance),
          });
        }
      }
      nearbyProviders.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );
      return nearbyProviders;
    });
  }

  Stream<ProviderModel?> getProviderDetails(String providerId) {
    return _providers.doc(providerId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ProviderModel.fromFirestore(doc);
    });
  }

  // ========== SERVICE BOOKINGS ==========

  Future<String> createBookingRequest({
    required String providerId,
    required String serviceCategory,
    required String serviceDescription,
    required DateTime scheduledTime,
    required String customerAddress,
    required double customerLat,
    required double customerLng,
    String? specialInstructions,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    final bookingRef = _serviceBookings.doc();
    await bookingRef.set({
      'customerId': currentUser.uid,
      'providerId': providerId,
      'serviceCategory': serviceCategory,
      'serviceDescription': serviceDescription,
      'scheduledTime': Timestamp.fromDate(scheduledTime),
      'customerAddress': customerAddress,
      'customerLocation': {'latitude': customerLat, 'longitude': customerLng},
      'specialInstructions': specialInstructions ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    Log.i('ServiceProviderService', 'Booking request created: ${bookingRef.id}');
    return bookingRef.id;
  }

  Stream<List<Map<String, dynamic>>> getUserBookings() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _serviceBookings
        .where('customerId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final Map<String, dynamic> data =
                doc.data();
            final Map<String, dynamic> bookingMap = Map<String, dynamic>.from(
              data,
            );
            bookingMap['id'] = doc.id;
            return bookingMap;
          }).toList();
        });
  }

  // ========== PROVIDER OFFERS ==========

  Future<String> submitProviderOffer({
    required String bookingId,
    required String providerId,
    required double offeredPrice,
    required String estimatedTime,
    String? message,
  }) async {
    final offerRef = _providerOffers.doc();
    await offerRef.set({
      'bookingId': bookingId,
      'providerId': providerId,
      'offeredPrice': offeredPrice,
      'estimatedTime': estimatedTime,
      'message': message ?? '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    Log.i('ServiceProviderService', 'Provider offer submitted: ${offerRef.id}');
    return offerRef.id;
  }

  Stream<List<Map<String, dynamic>>> getBookingOffers(String bookingId) {
    return _providerOffers
        .where('bookingId', isEqualTo: bookingId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final Map<String, dynamic> data =
                doc.data();
            final Map<String, dynamic> offerMap = Map<String, dynamic>.from(
              data,
            );
            offerMap['id'] = doc.id;
            return offerMap;
          }).toList();
        });
  }

  Future<void> acceptOffer(String offerId, String bookingId) async {
    await _providerOffers.doc(offerId).update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _serviceBookings.doc(bookingId).update({
      'status': 'provider_assigned',
      'acceptedOfferId': offerId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    Log.i('ServiceProviderService', 'Offer accepted: $offerId');
  }

  // ========== REVIEWS & RATINGS ==========

  Future<void> addReview({
    required String providerId,
    required String bookingId,
    required double rating,
    required String comment,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    await _firestore.collection('reviews').add({
      'providerId': providerId,
      'bookingId': bookingId,
      'customerId': currentUser.uid,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _updateProviderRating(providerId);
    Log.i('ServiceProviderService', 'Review added for provider: $providerId');
  }

  Stream<List<Map<String, dynamic>>> getProviderReviews(String providerId) {
    return _firestore
        .collection('reviews')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final Map<String, dynamic> reviewMap = Map<String, dynamic>.from(
              doc.data(),
            );
            reviewMap['id'] = doc.id;
            return reviewMap;
          }).toList();
        });
  }

  Future<void> _updateProviderRating(String providerId) async {
    final reviewsSnapshot = await _firestore
        .collection('reviews')
        .where('providerId', isEqualTo: providerId)
        .get();
    if (reviewsSnapshot.docs.isEmpty) return;

    double totalRating = 0;
    for (final doc in reviewsSnapshot.docs) {
      totalRating += (doc.data()['rating'] as num).toDouble();
    }

    final averageRating = totalRating / reviewsSnapshot.docs.length;
    await _providers.doc(providerId).update({
      'rating': averageRating,
      'totalReviews': reviewsSnapshot.docs.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ========== HELPER METHODS ==========

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  double _sin(double x) => x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  double _cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;
  double _sqrt(double x) {
    if (x == 0) return 0;
    double result = x;
    for (int i = 0; i < 10; i++) {
      result = (result + x / result) / 2;
    }
    return result;
  }

  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }

  double _atan(double x) => x - (x * x * x) / 3 + (x * x * x * x * x) / 5;

  String _calculateETA(double distanceInKm) {
    final timeInMinutes = (distanceInKm / 30 * 60).round();
    if (timeInMinutes < 15) return '15 mins';
    if (timeInMinutes < 30) return '30 mins';
    if (timeInMinutes < 45) return '45 mins';
    if (timeInMinutes < 60) return '1 hour';
    return '${(timeInMinutes / 60).round()} hours';
  }
}
