import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Service for calculating ETA and distance between locations
class ETACalculatorService {
  static final ETACalculatorService _instance = ETACalculatorService._internal();
  factory ETACalculatorService() => _instance;
  ETACalculatorService._internal();

  /// Average speeds in km/h for different vehicles
  static const double bikeSpeed = 30.0;
  static const double carSpeed = 25.0;
  static const double autoSpeed = 20.0;
  static const double walkingSpeed = 5.0;

  /// Calculate distance between two coordinates in kilometers
  double calculateDistance({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return Geolocator.distanceBetween(
      fromLat,
      fromLng,
      toLat,
      toLng,
    ) / 1000; // Convert meters to kilometers
  }

  /// Calculate ETA in minutes based on distance and vehicle type
  int calculateETA({
    required double distanceKm,
    String vehicleType = 'bike',
  }) {
    double speed = _getVehicleSpeed(vehicleType);
    
    // Time in hours = distance / speed
    double timeInHours = distanceKm / speed;
    
    // Convert to minutes
    int timeInMinutes = (timeInHours * 60).ceil();
    
    // Add buffer time for traffic and stops (20%)
    int bufferTime = (timeInMinutes * 0.2).ceil();
    
    return timeInMinutes + bufferTime;
  }

  /// Get speed for vehicle type
  double _getVehicleSpeed(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'bike':
      case 'motorcycle':
        return bikeSpeed;
      case 'car':
      case 'taxi':
        return carSpeed;
      case 'auto':
      case 'rickshaw':
        return autoSpeed;
      default:
        return bikeSpeed;
    }
  }

  /// Format distance for display
  String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }

  /// Format ETA for display
  String formatETA(int minutes) {
    if (minutes < 60) {
      return '$minutes mins';
    } else {
      int hours = minutes ~/ 60;
      int mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
  }

  /// Calculate both distance and ETA
  Map<String, dynamic> calculateDistanceAndETA({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String vehicleType = 'bike',
  }) {
    double distance = calculateDistance(
      fromLat: fromLat,
      fromLng: fromLng,
      toLat: toLat,
      toLng: toLng,
    );

    int eta = calculateETA(
      distanceKm: distance,
      vehicleType: vehicleType,
    );

    return {
      'distance': distance,
      'distanceFormatted': formatDistance(distance),
      'eta': eta,
      'etaFormatted': formatETA(eta),
    };
  }

  /// Haversine formula for more accurate distance calculation
  double haversineDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  double sin(double x) => _sin(x);
  double cos(double x) => _cos(x);
  double sqrt(double x) => _sqrt(x);
  double atan2(double y, double x) => _atan2(y, x);

  // Using dart:math implementations
  double _sin(double x) {
    var result = 0.0;
    var term = x;
    var xSquared = x * x;
    for (var i = 1; i <= 10; i++) {
      result += term;
      term *= -xSquared / ((2 * i) * (2 * i + 1));
    }
    return result;
  }

  double _cos(double x) {
    var result = 1.0;
    var term = 1.0;
    var xSquared = x * x;
    for (var i = 1; i <= 10; i++) {
      term *= -xSquared / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _sqrt(double x) {
    if (x < 0) return double.nan;
    if (x == 0) return 0;
    
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0) {
      if (y >= 0) return _atan(y / x) + 3.141592653589793;
      return _atan(y / x) - 3.141592653589793;
    }
    if (y > 0) return 3.141592653589793 / 2;
    if (y < 0) return -3.141592653589793 / 2;
    return 0;
  }

  double _atan(double x) {
    var result = 0.0;
    var term = x;
    var xSquared = x * x;
    for (var i = 0; i <= 10; i++) {
      result += term / (2 * i + 1);
      term *= -xSquared;
    }
    return result;
  }
}
