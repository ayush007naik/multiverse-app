import 'dart:math';
import 'package:flutter/foundation.dart';

/// Unified Delivery Fee Calculation Service
/// 
/// This service ensures delivery fee is calculated ONLY ONCE
/// and the same value is used across Cart → Checkout → Payment
/// 
/// Flow:
/// 1. Cart screen calls calculateDeliveryFee()
/// 2. Result is passed to Checkout screen
/// 3. Checkout passes SAME values to Payment screen
/// 4. NO recalculation on different screens
class DeliveryFeeService {
  // Configuration
  static const double baseFare = 20.0; // Base fare in ₹
  static const double perKmRate = 5.0; // Per km rate in ₹
  static const double minimumFee = 30.0; // Minimum delivery fee

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance({
    required double userLat,
    required double userLng,
    required double shopLat,
    required double shopLng,
  }) {
    const double earthRadiusKm = 6371.0;

    final double dLat = _degreesToRadians(shopLat - userLat);
    final double dLng = _degreesToRadians(shopLng - userLng);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(userLat)) *
            cos(_degreesToRadians(shopLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Calculate delivery fee based on distance
  /// Formula: Base Fare + (Distance × Per KM Rate)
  /// Minimum: minimumFee
  static double calculateFeeFromDistance(double distanceKm) {
    final double calculatedFee = baseFare + (distanceKm * perKmRate);
    final double fee = max(calculatedFee, minimumFee);
    
    debugPrint('📍 [DeliveryFee] Distance: ${distanceKm.toStringAsFixed(2)} km');
    debugPrint('💰 [DeliveryFee] Fee: ₹${fee.toStringAsFixed(0)} (Base: ₹$baseFare + ${distanceKm.toStringAsFixed(1)}km × ₹$perKmRate)');
    
    return fee;
  }

  /// Complete delivery calculation - Call this ONCE in Cart screen
  /// Returns all values needed for the entire checkout flow
  static DeliveryFeeResult calculate({
    required double userLat,
    required double userLng,
    required double shopLat,
    required double shopLng,
  }) {
    // Step 1: Calculate distance
    final double distance = calculateDistance(
      userLat: userLat,
      userLng: userLng,
      shopLat: shopLat,
      shopLng: shopLng,
    );

    // Step 2: Calculate delivery fee (ONLY ONCE)
    final double deliveryFee = calculateFeeFromDistance(distance);

    // Step 3: Return result object
    final result = DeliveryFeeResult(
      distance: distance,
      deliveryFee: deliveryFee,
    );

    debugPrint('✅ [DeliveryFee] Calculation complete: ${result.toString()}');
    return result;
  }

  /// Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).toStringAsFixed(0)}m';
    } else if (distanceKm < 10.0) {
      return '${distanceKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceKm.toStringAsFixed(0)}km';
    }
  }

  /// Estimate delivery time based on distance
  static String estimateDeliveryTime(double distanceKm) {
    const double avgSpeedKmh = 30.0;
    const double pickupTime = 10.0;
    const double bufferTime = 5.0;

    final double travelTime = (distanceKm / avgSpeedKmh) * 60;
    final double totalTime = pickupTime + travelTime + bufferTime;

    if (totalTime < 15) {
      return '10-15 mins';
    } else if (totalTime < 30) {
      return '15-30 mins';
    } else if (totalTime < 45) {
      return '30-45 mins';
    } else if (totalTime < 60) {
      return '45-60 mins';
    } else {
      final int hours = (totalTime / 60).floor();
      final int mins = (totalTime % 60).floor();
      return '$hours h ${mins} m';
    }
  }
}

/// Result object for delivery fee calculation
/// Pass this object through Cart → Checkout → Payment
class DeliveryFeeResult {
  final double distance; // in km
  final double deliveryFee; // in ₹

  DeliveryFeeResult({
    required this.distance,
    required this.deliveryFee,
  });

  @override
  String toString() {
    return 'DeliveryFeeResult(distance: ${distance.toStringAsFixed(2)}km, fee: ₹${deliveryFee.toStringAsFixed(0)})';
  }

  /// Convert to Map for passing between screens
  Map<String, dynamic> toMap() {
    return {
      'distance': distance,
      'deliveryFee': deliveryFee,
    };
  }

  /// Create from Map
  factory DeliveryFeeResult.fromMap(Map<String, dynamic> map) {
    return DeliveryFeeResult(
      distance: (map['distance'] as num).toDouble(),
      deliveryFee: (map['deliveryFee'] as num).toDouble(),
    );
  }
}
