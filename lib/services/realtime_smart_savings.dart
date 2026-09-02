import 'package:geolocator/geolocator.dart';

/// Realtime Smart Savings Calculator
/// Calculates actual savings based on:
/// - User's live location
/// - Shop location (lat/lng)
/// - Distance calculation
/// - Fuel cost estimation
/// - Travel time estimation
class RealtimeSmartSavings {
  // Constants
  static const double avgMileage = 12.0; // km per liter
  static const double petrolPrice = 100.0; // ₹ per liter
  static const double avgSpeed = 30.0; // km/h in city traffic
  static const int shoppingTimePerItem = 5; // minutes per item
  static const int baseShoppingTime = 20; // base time in store

  // Cache
  static DateTime? _lastCalculationTime;
  static RealtimeSavingsResult? _cachedResult;
  static const Duration cacheValidity = Duration(minutes: 5);

  /// Calculate realtime savings based on user location and shop location
  static Future<RealtimeSavingsResult> calculateSavings({
    required List<Map<String, dynamic>> cartItems,
    double? shopLat,
    double? shopLng,
  }) async {
    // Check cache validity
    if (_cachedResult != null && _lastCalculationTime != null) {
      final cacheAge = DateTime.now().difference(_lastCalculationTime!);
      if (cacheAge < cacheValidity) {
        return _cachedResult!;
      }
    }

    try {
      // 1. Get user's current location
      Position? userPosition;
      try {
        userPosition = await _getCurrentLocation();
      } catch (e) {
        // If location fails, use fallback calculation
        return _calculateFallbackSavings(cartItems);
      }

      if (userPosition == null || shopLat == null || shopLng == null) {
        return _calculateFallbackSavings(cartItems);
      }

      // 2. Calculate actual distance
      final distanceOneWay =
          Geolocator.distanceBetween(
            userPosition.latitude,
            userPosition.longitude,
            shopLat,
            shopLng,
          ) /
          1000; // Convert to km

      final totalDistance = distanceOneWay * 2; // Round trip

      // 3. Calculate fuel cost
      final fuelUsed = totalDistance / avgMileage;
      final fuelCostSaved = fuelUsed * petrolPrice;

      // 4. Calculate time saved
      final travelTimeMinutes = (totalDistance / avgSpeed) * 60;
      final itemCount = cartItems.length;
      final shoppingTime = baseShoppingTime + (itemCount * shoppingTimePerItem);
      final totalTimeSaved = travelTimeMinutes + shoppingTime;

      // 5. Build result
      final result = RealtimeSavingsResult(
        totalDistance: totalDistance,
        fuelCostSaved: fuelCostSaved,
        timeSavedMinutes: totalTimeSaved.toInt(),
        itemCount: itemCount,
        isRealtime: true,
      );

      // Cache the result
      _cachedResult = result;
      _lastCalculationTime = DateTime.now();

      return result;
    } catch (e) {
      return _calculateFallbackSavings(cartItems);
    }
  }

  /// Get user's current location
  static Future<Position?> _getCurrentLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position with timeout
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('Location request timed out'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Fallback calculation when location is not available
  static RealtimeSavingsResult _calculateFallbackSavings(
    List<Map<String, dynamic>> cartItems,
  ) {
    // Use average distance (8km round trip)
    const fallbackDistance = 8.0;
    const fuelUsed = fallbackDistance / avgMileage;
    const fuelCostSaved = fuelUsed * petrolPrice;
    const timeSaved = 60; // 1 hour average

    return RealtimeSavingsResult(
      totalDistance: fallbackDistance,
      fuelCostSaved: fuelCostSaved,
      timeSavedMinutes: timeSaved,
      itemCount: cartItems.length,
      isRealtime: false,
    );
  }

  /// Clear cache (call when cart/shop/address changes)
  static void clearCache() {
    _cachedResult = null;
    _lastCalculationTime = null;
  }
}

/// Result class for realtime savings calculation
class RealtimeSavingsResult {
  final double totalDistance; // km
  final double fuelCostSaved; // ₹
  final int timeSavedMinutes;
  final int itemCount;
  final bool isRealtime; // true if calculated from actual location

  RealtimeSavingsResult({
    required this.totalDistance,
    required this.fuelCostSaved,
    required this.timeSavedMinutes,
    required this.itemCount,
    required this.isRealtime,
  });

  /// Formatted fuel cost saved
  String get formattedFuelCost => '₹${fuelCostSaved.toStringAsFixed(0)}';

  /// Formatted time saved
  String get formattedTime {
    if (timeSavedMinutes >= 60) {
      final hours = timeSavedMinutes ~/ 60;
      final minutes = timeSavedMinutes % 60;
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    }
    return '${timeSavedMinutes}m';
  }

  /// Formatted distance
  String get formattedDistance => '${totalDistance.toStringAsFixed(1)}km';

  /// Main savings message
  String get savingsMessage => 'You saved $formattedFuelCost';

  /// Subtitle message
  String get subtitleMessage => 'Compared to visiting stores yourself';

  /// Detailed breakdown messages
  List<String> get breakdownMessages => [
    '$formattedFuelCost fuel/travel cost saved',
    '$formattedTime saved',
    'No need to visit ${_calculateStoreVisits()} stores',
    '$formattedDistance travel avoided',
  ];

  /// Estimate number of store visits needed
  int _calculateStoreVisits() {
    if (itemCount <= 3) return 1;
    if (itemCount <= 6) return 2;
    return 3;
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}
