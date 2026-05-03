import 'package:flutter/foundation.dart';

/// Business logic for pricing, delivery fees, and calculations
class PricingService {
  // Base rates
  static const double baseRatePerKm = 20.0; // ₹20 per km
  static const double minimumDeliveryFee = 30.0; // Minimum ₹30
  
  // GST rate
  static const double gstRate = 0.18; // 18%
  
  // Commission split
  static const double deliveryPartnerShare = 0.80; // 80%
  static const double platformCommission = 0.20; // 20%
  
  // Special rules
  static const double freeDeliveryThreshold = 500.0; // Free delivery for orders > ₹500
  static const double longDistanceThreshold = 10.0; // >10km is long distance
  static const double longDistanceDiscount = 0.05; // 5% discount
  static const int deliveryTimeLimitMinutes = 45; // Delayed if >45 min
  static const double delayedCashback = 0.10; // 10% cashback

  /// Calculate delivery fee based on distance
  static double calculateDeliveryFee(double distanceKm) {
    double fee = distanceKm * baseRatePerKm;
    return fee < minimumDeliveryFee ? minimumDeliveryFee : fee;
  }

  /// Calculate GST (18% of subtotal + delivery fee)
  static double calculateGST(double subtotal, double deliveryFee) {
    return gstRate * (subtotal + deliveryFee);
  }

  /// Calculate final total
  static double calculateTotal(double subtotal, double deliveryFee, double gst) {
    return subtotal + deliveryFee + gst;
  }

  /// Apply free delivery if order value exceeds threshold
  static double applyFreeDeliveryRule(double subtotal, double deliveryFee) {
    if (subtotal >= freeDeliveryThreshold) {
      debugPrint('🎉 [PricingService] Free delivery applied! Order > ₹$freeDeliveryThreshold');
      return 0;
    }
    return deliveryFee;
  }

  /// Apply long distance discount (5% off for >10km)
  static double applyLongDistanceDiscount(double deliveryFee, double distanceKm) {
    if (distanceKm > longDistanceThreshold) {
      double discount = deliveryFee * longDistanceDiscount;
      double finalFee = deliveryFee - discount;
      debugPrint('🚗 [PricingService] Long distance discount: -₹${discount.toStringAsFixed(0)}');
      return finalFee;
    }
    return deliveryFee;
  }

  /// Calculate delivery partner earnings (80% of delivery fee)
  static double calculateDeliveryPartnerEarnings(double deliveryFee) {
    return deliveryFee * deliveryPartnerShare;
  }

  /// Calculate platform commission (20% of delivery fee)
  static double calculatePlatformCommission(double deliveryFee) {
    return deliveryFee * platformCommission;
  }

  /// Calculate delayed cashback (10% if delivery >45 min)
  static double calculateDelayedCashback(double total, bool isDelayed) {
    if (isDelayed) {
      double cashback = total * delayedCashback;
      debugPrint('⏰ [PricingService] Delayed delivery cashback: ₹${cashback.toStringAsFixed(0)}');
      return cashback;
    }
    return 0;
  }

  /// Complete pricing calculation with all rules
  static Map<String, double> calculateCompletePricing({
    required double subtotal,
    required double distanceKm,
    bool isDelayed = false,
  }) {
    // Step 1: Calculate base delivery fee
    double deliveryFee = calculateDeliveryFee(distanceKm);
    
    // Step 2: Apply free delivery rule
    deliveryFee = applyFreeDeliveryRule(subtotal, deliveryFee);
    
    // Step 3: Apply long distance discount
    deliveryFee = applyLongDistanceDiscount(deliveryFee, distanceKm);
    
    // Step 4: Calculate GST
    double gst = calculateGST(subtotal, deliveryFee);
    
    // Step 5: Calculate total
    double total = calculateTotal(subtotal, deliveryFee, gst);
    
    // Step 6: Calculate splits
    double partnerEarnings = calculateDeliveryPartnerEarnings(deliveryFee);
    double platformEarned = calculatePlatformCommission(deliveryFee);
    
    // Step 7: Calculate delayed cashback if applicable
    double cashback = calculateDelayedCashback(total, isDelayed);
    
    debugPrint('💰 [PricingService] Complete Pricing:');
    debugPrint('   Subtotal: ₹${subtotal.toStringAsFixed(0)}');
    debugPrint('   Delivery Fee: ₹${deliveryFee.toStringAsFixed(0)}');
    debugPrint('   GST (18%): ₹${gst.toStringAsFixed(0)}');
    debugPrint('   Total: ₹${total.toStringAsFixed(0)}');
    debugPrint('   Partner Earnings (80%): ₹${partnerEarnings.toStringAsFixed(0)}');
    debugPrint('   Platform Commission (20%): ₹${platformEarned.toStringAsFixed(0)}');
    if (cashback > 0) {
      debugPrint('   Delayed Cashback: ₹${cashback.toStringAsFixed(0)}');
    }
    
    return {
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'gst': gst,
      'total': total,
      'partnerEarnings': partnerEarnings,
      'platformCommission': platformEarned,
      'cashback': cashback,
    };
  }

  /// Format currency for display
  static String formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  /// Check if order qualifies for free delivery
  static bool isFreeDeliveryEligible(double subtotal) {
    return subtotal >= freeDeliveryThreshold;
  }

  /// Get delivery fee breakdown text
  static String getDeliveryFeeBreakdown(double distanceKm, double subtotal) {
    double baseFee = calculateDeliveryFee(distanceKm);
    double finalFee = applyFreeDeliveryRule(subtotal, baseFee);
    finalFee = applyLongDistanceDiscount(finalFee, distanceKm);
    
    if (finalFee == 0) {
      return 'FREE (Order > ₹${freeDeliveryThreshold.toStringAsFixed(0)})';
    }
    
    String breakdown = formatCurrency(finalFee);
    
    if (distanceKm > longDistanceThreshold) {
      breakdown += ' (5% long-distance discount applied)';
    }
    
    return breakdown;
  }
}
