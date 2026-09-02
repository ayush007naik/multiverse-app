import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/provider_model.dart';
import '../core/logging_service.dart';

/// Provider Service
/// Handles provider discovery, availability, and real-time updates
class ProviderService {
  static final ProviderService _instance = ProviderService._internal();
  factory ProviderService() => _instance;
  ProviderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _providers => _firestore.collection('providers');
  CollectionReference get _users => _firestore.collection('users');

  // ========== PROVIDER DISCOVERY ==========

  /// Get nearby providers for a service category
  /// Uses geolocation to find providers within range
  Stream<List<ProviderModel>> getNearbyProviders({
    required double latitude,
    required double longitude,
    required String serviceCategory,
    double radiusInKm = 10.0,
  }) {
    // Note: Firestore doesn't support native geospatial queries yet
    // This is a simplified version - in production, use GeoFlutterFire or Algolia

    return _providers
        .where('serviceCategories', arrayContains: serviceCategory)
        .where('isAvailable', isEqualTo: true)
        .where('isVerified', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final providers = snapshot.docs
              .map((doc) => ProviderModel.fromFirestore(doc))
              .toList();

          // Filter by distance client-side
          // In production, use Cloud Functions for server-side filtering
          return providers.where((provider) {
            if (provider.location == null) return false;

            final distance = _calculateDistance(
              latitude,
              longitude,
              provider.location!['latitude'],
              provider.location!['longitude'],
            );

            return distance <= radiusInKm;
          }).toList()..sort((a, b) {
            // Sort by rating and distance
            final ratingDiff = b.rating.compareTo(a.rating);
            if (ratingDiff != 0) return ratingDiff;

            final distA = _calculateDistance(
              latitude,
              longitude,
              a.location!['latitude'],
              a.location!['longitude'],
            );
            final distB = _calculateDistance(
              latitude,
              longitude,
              b.location!['latitude'],
              b.location!['longitude'],
            );
            return distA.compareTo(distB);
          });
        });
  }

  /// Get providers by service category (no location filter)
  Stream<List<ProviderModel>> getProvidersByCategory(String category) {
    return _providers
        .where('serviceCategories', arrayContains: category)
        .where('isAvailable', isEqualTo: true)
        .where('isVerified', isEqualTo: true)
        .orderBy('rating', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ProviderModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Get top-rated providers
  Stream<List<ProviderModel>> getTopProviders({
    String? category,
    int limit = 10,
  }) {
    var query = _providers
        .where('isVerified', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .orderBy('rating', descending: true)
        .orderBy('completedJobs', descending: true)
        .limit(limit);

    if (category != null) {
      query = query.where('serviceCategories', arrayContains: category);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ProviderModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Get a specific provider by ID
  Stream<ProviderModel?> listenToProvider(String providerId) {
    return _providers.doc(providerId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return ProviderModel.fromFirestore(snapshot);
    });
  }

  /// Get provider by user ID
  Future<ProviderModel?> getProviderByUserId(String userId) async {
    try {
      final snapshot = await _providers
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return ProviderModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      Log.e('ProviderService', '❌ Error fetching provider: $e', ex: e);
      return null;
    }
  }

  // ========== PROVIDER AVAILABILITY ==========

  /// Update provider online status
  Future<void> updateProviderOnlineStatus(bool isOnline) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final provider = await getProviderByUserId(userId);
      if (provider == null) throw Exception('Provider profile not found');

      await _providers.doc(provider.id).update({
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      });

      Log.i(
        'ProviderService',
        '✅ Provider status updated: ${isOnline ? "Online" : "Offline"}',
      );
    } catch (e) {
      Log.e('ProviderService', '❌ Error updating provider status: $e', ex: e);
      rethrow;
    }
  }

  /// Toggle provider availability
  Future<void> toggleAvailability(bool isAvailable) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final provider = await getProviderByUserId(userId);
      if (provider == null) throw Exception('Provider profile not found');

      await _providers.doc(provider.id).update({
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Log.i(
        'ProviderService',
        '✅ Provider availability: ${isAvailable ? "Available" : "Unavailable"}',
      );
    } catch (e) {
      Log.e('ProviderService', '❌ Error toggling availability: $e', ex: e);
      rethrow;
    }
  }

  /// Update provider location in real-time
  Future<void> updateProviderLocation({
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final provider = await getProviderByUserId(userId);
      if (provider == null) throw Exception('Provider profile not found');

      await _providers.doc(provider.id).update({
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      Log.e('ProviderService', '❌ Error updating location: $e', ex: e);
      rethrow;
    }
  }

  // ========== PROVIDER REGISTRATION ==========

  /// Create a new provider profile
  Future<String> createProviderProfile({
    required String name,
    required String phone,
    required List<String> serviceCategories,
    required List<String> services,
    String? bio,
    int yearsOfExperience = 0,
    double basePrice = 0.0,
    Map<String, dynamic>? location,
    Map<String, dynamic>? workingHours,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final provider = ProviderModel(
        id: '',
        userId: userId,
        name: name,
        phone: phone,
        serviceCategories: serviceCategories,
        services: services,
        bio: bio ?? '',
        yearsOfExperience: yearsOfExperience,
        basePrice: basePrice,
        location: location,
        workingHours: workingHours,
        isAvailable: false, // Start as unavailable until verified
        isVerified: false, // Requires admin approval
        isOnline: false,
        createdAt: DateTime.now(),
      );

      final docRef = await _providers.add(provider.toMap());

      // Update user role to provider
      await _users.doc(userId).update({'role': 'provider'});

      Log.i('ProviderService', '✅ Provider profile created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      Log.e('ProviderService', '❌ Error creating provider profile: $e', ex: e);
      rethrow;
    }
  }

  /// Update provider profile
  Future<void> updateProviderProfile({
    required String providerId,
    String? bio,
    List<String>? serviceCategories,
    List<String>? services,
    int? yearsOfExperience,
    double? basePrice,
    Map<String, dynamic>? workingHours,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (bio != null) updates['bio'] = bio;
      if (serviceCategories != null) {
        updates['serviceCategories'] = serviceCategories;
      }
      if (services != null) updates['services'] = services;
      if (yearsOfExperience != null) {
        updates['yearsOfExperience'] = yearsOfExperience;
      }
      if (basePrice != null) updates['basePrice'] = basePrice;
      if (workingHours != null) updates['workingHours'] = workingHours;

      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _providers.doc(providerId).update(updates);
      Log.i('ProviderService', '✅ Provider profile updated');
    } catch (e) {
      Log.e('ProviderService', '❌ Error updating provider profile: $e', ex: e);
      rethrow;
    }
  }

  // ========== PROVIDER STATS ==========

  /// Get provider statistics
  Future<Map<String, dynamic>> getProviderStats(String providerId) async {
    try {
      final providerDoc = await _providers.doc(providerId).get();
      if (!providerDoc.exists) throw Exception('Provider not found');

      final provider = ProviderModel.fromFirestore(providerDoc);

      // Get bookings count
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('providerId', isEqualTo: providerId)
          .get();

      final completedBookings = bookingsSnapshot.docs
          .where((doc) => doc['status'] == 'service_completed')
          .length;

      final totalEarnings = bookingsSnapshot.docs
          .where((doc) => doc['status'] == 'service_completed')
          .fold<double>(0.0, (sum, doc) => sum + (doc['acceptedPrice'] ?? 0.0));

      return {
        'totalBookings': bookingsSnapshot.docs.length,
        'completedBookings': completedBookings,
        'cancelledBookings': bookingsSnapshot.docs.length - completedBookings,
        'rating': provider.rating,
        'totalReviews': provider.totalReviews,
        'totalEarnings': totalEarnings,
        'completedJobs': provider.completedJobs,
      };
    } catch (e) {
      Log.e('ProviderService', '❌ Error fetching provider stats: $e', ex: e);
      rethrow;
    }
  }

  // ========== HELPER METHODS ==========

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km

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

  double _atan(double x) {
    return x - (x * x * x) / 3 + (x * x * x * x * x) / 5;
  }
}
