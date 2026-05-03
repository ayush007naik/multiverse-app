//  lib/utils/delivery_fee_calculator.dart
// ✅ Delivery Fee Calculator - Distance-based calculation

import 'dart:math';

class DeliveryFeeCalculator {
  // Configuration
  static const double BASE_DELIVERY_FEE = 30.0; // Base fee in rupees
  static const double PER_KM_RATE = 5.0; // Rate per km in rupees
  static const double MINIMUM_DELIVERY_FEE = 30.0; // Minimum fee to charge
  
  // Delivery type constants
  static const String normalDeliveryType = 'normal';
  static const String expressDeliveryType = 'express';
  static const String heavyDeliveryType = 'heavy';
  
  // Vehicle type constants
  static const String bikeVehicle = 'bike';
  static const String carVehicle = 'car';
  static const String autoVehicle = 'auto';
  static const String truckVehicle = 'truck';

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance({
    required double userLat,
    required double userLng,
    required double shopLat,
    required double shopLng,
  }) {
    const double earthRadiusKm = 6371.0; // Earth's radius in kilometers

    // Convert degrees to radians
    final double dLat = _degreesToRadians(shopLat - userLat);
    final double dLng = _degreesToRadians(shopLng - userLng);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(userLat)) *
            cos(_degreesToRadians(shopLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = earthRadiusKm * c;

    return distance;
  }

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Calculate delivery fee based on distance
  /// Formula: Base Fee + (Distance × Per KM Rate)
  /// Minimum: MINIMUM_DELIVERY_FEE
  static double calculateDeliveryFee({
    required double distance,
    double? customBaseFee,
    double? customPerKmRate,
    double? customMinFee,
  }) {
    final double baseFee = customBaseFee ?? BASE_DELIVERY_FEE;
    final double perKmRate = customPerKmRate ?? PER_KM_RATE;
    final double minFee = customMinFee ?? MINIMUM_DELIVERY_FEE;

    // Calculate fee: base + (distance * per km rate)
    final double calculatedFee = baseFee + (distance * perKmRate);

    // Return the maximum of calculated fee and minimum fee
    return max(calculatedFee, minFee);
  }

  /// Get formatted distance string
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      // Less than 1km - show in meters
      return '${(distanceKm * 1000).toStringAsFixed(0)}m';
    } else if (distanceKm < 10.0) {
      // Show with 1 decimal place
      return '${distanceKm.toStringAsFixed(1)}km';
    } else {
      // Show as integer
      return '${distanceKm.toStringAsFixed(0)}km';
    }
  }

  /// Get estimated delivery fee string
  static String formatDeliveryFee(double fee) {
    return '₹${fee.toStringAsFixed(0)}';
  }

  /// Complete calculation: distance + fee
  static Map<String, dynamic> calculateComplete({
    required double userLat,
    required double userLng,
    required double shopLat,
    required double shopLng,
    String deliveryType = normalDeliveryType,
    double? customBaseFee,
    double? customPerKmRate,
    double? customMinFee,
  }) {
    // Calculate distance
    final double distance = calculateDistance(
      userLat: userLat,
      userLng: userLng,
      shopLat: shopLat,
      shopLng: shopLng,
    );

    // Calculate delivery fee
    final double deliveryFee = calculateDeliveryFee(
      distance: distance,
      customBaseFee: customBaseFee,
      customPerKmRate: customPerKmRate,
      customMinFee: customMinFee,
    );

    return {
      'distance': distance,
      'distanceFormatted': formatDistance(distance),
      'deliveryFee': deliveryFee,
      'deliveryFeeFormatted': formatDeliveryFee(deliveryFee),
      'estimatedTime': estimateDeliveryTime(distance),
      'deliveryType': deliveryType,
    };
  }

  /// Estimate delivery time based on distance
  /// Assumption: Average speed is 30 km/h in city
  static String estimateDeliveryTime(double distanceKm) {
    const double avgSpeedKmh = 30.0; // Average speed in km/h
    const double pickupTime = 10.0; // Minutes to pick up order
    const double bufferTime = 5.0; // Buffer time

    final double travelTime = (distanceKm / avgSpeedKmh) * 60; // Convert to minutes
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

  /// Get delivery fee breakdown for display
  static String getDeliveryFeeBreakdown({
    required double distance,
    required double deliveryFee,
    double? customBaseFee,
    double? customPerKmRate,
  }) {
    final double baseFee = customBaseFee ?? BASE_DELIVERY_FEE;
    final double perKmRate = customPerKmRate ?? PER_KM_RATE;
    final double distanceFee = distance * perKmRate;

    return 'Base: ₹$baseFee + Distance (${formatDistance(distance)} × ₹$perKmRate) = ₹${deliveryFee.toStringAsFixed(0)}';
  }
  
  /// Detect delivery type based on cart items
  static String detectDeliveryType(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return normalDeliveryType;
    
    // Check if any item has heavy/bulky delivery type
    for (var item in items) {
      final deliveryType = (item['deliveryType'] as String? ?? '').toLowerCase();
      if (deliveryType == 'heavy' || deliveryType == 'bulky') {
        return heavyDeliveryType;
      }
    }
    
    return normalDeliveryType;
  }
  
  /// Normalize delivery type string
  static String normalizeDeliveryType(String? type) {
    if (type == null || type.isEmpty) return normalDeliveryType;
    
    final normalized = type.toLowerCase().trim();
    if (normalized == 'express' || normalized == 'fast') {
      return expressDeliveryType;
    } else if (normalized == 'heavy' || normalized == 'bulky') {
      return heavyDeliveryType;
    }
    return normalDeliveryType;
  }
  
  /// Get vehicle type for delivery type
  static String vehicleForDeliveryType(String deliveryType) {
    switch (deliveryType) {
      case heavyDeliveryType:
        return truckVehicle;
      case expressDeliveryType:
        return bikeVehicle;
      default:
        return bikeVehicle;
    }
  }
  
  /// Format vehicle type for display
  static String formatVehicle(String? vehicle) {
    if (vehicle == null || vehicle.isEmpty) return 'Bike';
    
    switch (vehicle.toLowerCase()) {
      case 'bike':
        return '🏍️ Bike';
      case 'car':
        return '🚗 Car';
      case 'auto':
        return '🛺 Auto';
      case 'truck':
        return '🚚 Truck';
      default:
        return '🏍️ Bike';
    }
  }
  
  /// Format delivery type for display
  static String formatDeliveryType(String? deliveryType) {
    if (deliveryType == null || deliveryType.isEmpty) return 'Normal';
    
    switch (deliveryType.toLowerCase()) {
      case 'normal':
        return 'Normal Delivery';
      case 'express':
        return '⚡ Express';
      case 'heavy':
        return '📦 Heavy/Bulky';
      default:
        return 'Normal Delivery';
    }
  }
}
