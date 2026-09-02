import 'package:db_compat/db_compat.dart';
import 'package:flutter/material.dart';
import '../utils/environment_config.dart';

/// Razorpay Payout Service
/// Handles vendor payouts using Razorpay Route (Fund Transfer API)
class RazorpayPayoutService {
  static final RazorpayPayoutService _instance = RazorpayPayoutService._();
  factory RazorpayPayoutService() => _instance;
  RazorpayPayoutService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔧 Razorpay Key ID from EnvironmentConfig
  static const String razorpayKeyId = EnvironmentConfig.razorpayKey;
  // REMOVED: razorpayKeySecret (Should never be on client side)

  static const String payoutAccountId = 'YOUR_PAYOUT_ACCOUNT_ID'; // From Razorpay dashboard

  /// Process a single vendor payout via Razorpay Route
  /// 
  /// Steps:
  /// 1. Create contact for vendor (if not exists)
  /// 2. Create fund account for vendor (bank/UPI)
  /// 3. Initiate payout transfer
  /// 4. Update Firestore with payout status
  Future<Map<String, dynamic>> processPayout({
    required String payoutId,
    required String vendorId,
    required double amount,
    required String method, // 'bank_transfer' or 'upi'
    required Map<String, dynamic> vendorDetails,
  }) async {
    try {
      debugPrint('💰 [RazorpayPayout] Processing payout: $payoutId');
      debugPrint('💰 [RazorpayPayout] Amount: ₹$amount');
      debugPrint('💰 [RazorpayPayout] Method: $method');

      // Step 1: Update payout status to 'processing'
      await _firestore.collection('payouts').doc(payoutId).update({
        'status': 'processing',
        'processingStartedAt': FieldValue.serverTimestamp(),
        'paymentGateway': 'razorpay_route',
      });

      // Step 2: Make API call to Razorpay Route
      // NOTE: This should be done via Cloud Functions for security
      // Direct API calls from client are NOT recommended in production
      
      final payoutResponse = await _initiateRazorpayPayout(
        payoutId: payoutId,
        vendorId: vendorId,
        amount: amount,
        method: method,
        vendorDetails: vendorDetails,
      );

      if (payoutResponse['success'] == true) {
        // Step 3: Update payout as completed
        await _firestore.collection('payouts').doc(payoutId).update({
          'status': 'completed',
          'razorpayPayoutId': payoutResponse['payout_id'],
          'completedAt': FieldValue.serverTimestamp(),
          'processedBy': 'razorpay_route',
        });

        // Step 4: Update vendor earnings as withdrawn
        await _updateVendorEarnings(vendorId, amount);

        debugPrint('✅ [RazorpayPayout] Payout successful: ${payoutResponse['payout_id']}');
        
        return {
          'success': true,
          'payout_id': payoutResponse['payout_id'],
          'message': 'Payout processed successfully',
        };
      } else {
        // Payout failed
        await _firestore.collection('payouts').doc(payoutId).update({
          'status': 'failed',
          'failureReason': payoutResponse['error'],
          'failedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('❌ [RazorpayPayout] Payout failed: ${payoutResponse['error']}');
        
        return {
          'success': false,
          'error': payoutResponse['error'],
        };
      }
    } catch (e) {
      debugPrint('❌ [RazorpayPayout] Error: $e');
      
      // Update payout status to failed
      await _firestore.collection('payouts').doc(payoutId).update({
        'status': 'failed',
        'failureReason': e.toString(),
        'failedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Initiate payout via Razorpay Route API
  /// 
  /// ⚠️ SECURITY WARNING: This should be implemented in Firebase Cloud Functions
  /// Never expose Razorpay secret key in client-side code
  Future<Map<String, dynamic>> _initiateRazorpayPayout({
    required String payoutId,
    required String vendorId,
    required double amount,
    required String method,
    required Map<String, dynamic> vendorDetails,
  }) async {
    // 📝 IMPLEMENTATION NOTE:
    // In production, this method should call a Firebase Cloud Function
    // The Cloud Function will:
    // 1. Authenticate the request
    // 2. Call Razorpay Route API with secret key
    // 3. Return the response
    //
    // Example Cloud Function URL:
    // https://us-central1-your-project.cloudfunctions.net/processPayout
    
    // For now, simulating the API call
    // Replace this with actual Cloud Function call
    
    return {
      'success': true,
      'payout_id': 'payout_${DateTime.now().millisecondsSinceEpoch}',
      'message': 'Payout initiated',
    };
  }

  /// Update vendor earnings after successful payout
  Future<void> _updateVendorEarnings(String vendorId, double amount) async {
    final vendorRef = _firestore.collection('vendors').doc(vendorId);
    
    await vendorRef.update({
      'totalWithdrawn': FieldValue.increment(amount),
      'availableBalance': FieldValue.increment(-amount),
      'lastPayoutAt': FieldValue.serverTimestamp(),
      'lastPayoutAmount': amount,
    });
  }

  /// Bulk process multiple payouts
  /// 
  /// Used by admin to process all pending payouts at once
  Future<Map<String, dynamic>> processBulkPayouts({
    required List<String> payoutIds,
    required String adminId,
  }) async {
    debugPrint('💰 [RazorpayPayout] Processing ${payoutIds.length} bulk payouts');

    int successCount = 0;
    int failedCount = 0;
    List<Map<String, dynamic>> results = [];

    for (final payoutId in payoutIds) {
      try {
        // Get payout details
        final payoutDoc = await _firestore.collection('payouts').doc(payoutId).get();
        
        if (!payoutDoc.exists) {
          failedCount++;
          results.add({
            'payoutId': payoutId,
            'success': false,
            'error': 'Payout not found',
          });
          continue;
        }

        final payoutData = payoutDoc.data()!;
        
        // Process individual payout
        final result = await processPayout(
          payoutId: payoutId,
          vendorId: payoutData['vendorId'],
          amount: (payoutData['amount'] as num).toDouble(),
          method: 'bank_transfer',
          vendorDetails: {
            'bankAccountNumber': payoutData['bankAccountNumber'] ?? '',
          },
        );

        if (result['success'] == true) {
          successCount++;
        } else {
          failedCount++;
        }

        results.add({
          'payoutId': payoutId,
          ...result,
        });
      } catch (e) {
        failedCount++;
        results.add({
          'payoutId': payoutId,
          'success': false,
          'error': e.toString(),
        });
      }
    }

    debugPrint('✅ [RazorpayPayout] Bulk payout complete: $successCount success, $failedCount failed');

    return {
      'success': true,
      'totalProcessed': payoutIds.length,
      'successCount': successCount,
      'failedCount': failedCount,
      'results': results,
    };
  }

  /// Get all pending payouts for admin dashboard
  Future<List<Map<String, dynamic>>> getPendingPayouts() async {
    final snapshot = await _firestore
        .collection('payouts')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  /// Get total payout amount pending
  Future<double> getTotalPendingAmount() async {
    final pendingPayouts = await getPendingPayouts();
    
    double total = 0;
    for (final payout in pendingPayouts) {
      total += (payout['amount'] as num).toDouble();
    }
    
    return total;
  }

  /// Get vendor's payout history
  Future<List<Map<String, dynamic>>> getVendorPayouts(String vendorId) async {
    final snapshot = await _firestore
        .collection('payouts')
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }
}
