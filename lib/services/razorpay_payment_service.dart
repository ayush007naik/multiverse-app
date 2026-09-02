import 'dart:async';
import 'dart:math';

/// Razorpay Payment Service
///
/// This service handles the complete Razorpay payment flow:
/// 1. Create order from backend
/// 2. Open Razorpay checkout
/// 3. Verify payment signature
/// 4. Handle success/failure

class RazorpayPaymentService {
  static final RazorpayPaymentService _instance =
      RazorpayPaymentService._internal();
  factory RazorpayPaymentService() => _instance;
  RazorpayPaymentService._internal();

  /// Create Razorpay Order from Backend
  ///
  /// Returns order_id that will be used to open Razorpay checkout

  static Future<Map<String, dynamic>> createOrder({
    required int amount,
    required String currency,
    required String receipt,
    required String customerName,
    required String customerContact,
    required String customerEmail,
    required String bookingId,
  }) async {
    try {
      // TODO: Replace with actual backend API call
      // Example:
      // final response = await http.post(
      //   Uri.parse('$_baseUrl/api/create-razorpay-order'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({
      //     'amount': amount,
      //     'currency': currency,
      //     'receipt': receipt,
      //     'customer_name': customerName,
      //     'customer_contact': customerContact,
      //     'customer_email': customerEmail,
      //     'booking_id': bookingId,
      //   }),
      // );
      //
      // if (response.statusCode == 200) {
      //   return jsonDecode(response.body);
      // } else {
      //   throw Exception('Failed to create order');
      // }

      // Mock response for testing
      await Future.delayed(const Duration(milliseconds: 500));
      return {
        'success': true,
        'order_id': 'order_${DateTime.now().millisecondsSinceEpoch}',
        'amount': amount,
        'currency': currency,
        'receipt': receipt,
      };
    } catch (e) {
      throw Exception('Failed to create Razorpay order: $e');
    }
  }

  /// Open Razorpay Payment Checkout
  ///
  /// This will open the native Razorpay checkout UI
  ///
  /// Parameters:
  /// - orderId: Order ID from backend
  /// - amount: Amount in rupees
  /// - customerName: Customer name
  /// - customerContact: Customer phone
  /// - customerEmail: Customer email
  /// - onSuccess: Callback on successful payment
  /// - onFailure: Callback on failed payment

  static Future<void> openCheckout({
    required String orderId,
    required int amount,
    required String customerName,
    required String customerContact,
    required String customerEmail,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(String) onFailure,
  }) async {
    try {
      // TODO: Uncomment when razorpay_flutter package is added
      //
      // var options = {
      //   'key': _razorpayKeyId,
      //   'amount': (amount * 100).toInt(), // Amount in paise
      //   'currency': 'INR',
      //   'name': 'Home Services Platform',
      //   'description': 'Service Booking Payment',
      //   'order_id': orderId,
      //   'retry': {'enabled': true, 'max_count': 3},
      //   'send_sms_hash': true,
      //   'prefill': {
      //     'contact': customerContact,
      //     'email': customerEmail,
      //     'name': customerName,
      //   },
      //   'external': {
      //     'wallets': ['paytm', 'phonepe', 'gpay', 'bhim'],
      //   },
      //   'theme': {
      //     'color': '#FF7A1A', // Orange theme
      //   },
      // };
      //
      // final razorpay = Razorpay();
      // razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (response) {
      //   onSuccess({
      //     'payment_id': response.paymentId,
      //     'order_id': response.orderId,
      //     'signature': response.signature,
      //   });
      // });
      // razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (response) {
      //   onFailure(response.message ?? 'Payment failed');
      // });
      // razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (response) {
      //   // Handle external wallet
      // });
      //
      // razorpay.open(options);

      // Mock payment for testing
      await _mockPaymentFlow(
        orderId: orderId,
        amount: amount,
        onSuccess: onSuccess,
        onFailure: onFailure,
      );
    } catch (e) {
      onFailure('Failed to open payment checkout: $e');
    }
  }

  /// Verify Payment Signature from Backend
  ///
  /// This verifies the payment authenticity

  static Future<bool> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      // TODO: Replace with actual backend verification
      // final response = await http.post(
      //   Uri.parse('$_baseUrl/api/verify-payment'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({
      //     'payment_id': paymentId,
      //     'order_id': orderId,
      //     'signature': signature,
      //   }),
      // );
      //
      // return response.statusCode == 200;

      // Mock verification
      await Future.delayed(const Duration(milliseconds: 300));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Mock Payment Flow for Testing
  ///
  /// Simulates the complete Razorpay payment flow

  static Future<void> _mockPaymentFlow({
    required String orderId,
    required int amount,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(String) onFailure,
  }) async {
    // Simulate payment processing time
    await Future.delayed(const Duration(seconds: 2));

    // 80% success rate for testing
    final random = Random();
    final isSuccess = random.nextDouble() < 0.8;

    if (isSuccess) {
      onSuccess({
        'payment_id': 'pay_${DateTime.now().millisecondsSinceEpoch}',
        'order_id': orderId,
        'signature': 'mock_signature_${DateTime.now().millisecondsSinceEpoch}',
      });
    } else {
      onFailure('Payment failed. Please try again.');
    }
  }

  /// Complete Payment Flow
  ///
  /// This is the main method to call from UI
  /// Handles: Create Order → Open Checkout → Verify → Return Result

  static Future<Map<String, dynamic>?> processPayment({
    required int amount,
    required String customerName,
    required String customerContact,
    required String customerEmail,
    required String bookingId,
  }) async {
    try {
      // Step 1: Create order
      final orderResponse = await createOrder(
        amount: amount,
        currency: 'INR',
        receipt: 'booking_$bookingId',
        customerName: customerName,
        customerContact: customerContact,
        customerEmail: customerEmail,
        bookingId: bookingId,
      );

      if (orderResponse['success'] != true) {
        throw Exception('Failed to create order');
      }

      final orderId = orderResponse['order_id'] as String;

      // Step 2: Open checkout and wait for result
      final completer = Completer<Map<String, dynamic>?>();

      await openCheckout(
        orderId: orderId,
        amount: amount,
        customerName: customerName,
        customerContact: customerContact,
        customerEmail: customerEmail,
        onSuccess: (paymentData) async {
          try {
            // Step 3: Verify payment
            final isVerified = await verifyPayment(
              paymentId: paymentData['payment_id'] as String,
              orderId: paymentData['order_id'] as String,
              signature: paymentData['signature'] as String,
            );

            if (isVerified) {
              completer.complete(paymentData);
            } else {
              completer.completeError('Payment verification failed');
            }
          } catch (e) {
            completer.completeError(e);
          }
        },
        onFailure: (error) {
          completer.completeError(error);
        },
      );

      return await completer.future;
    } catch (e) {
      rethrow;
    }
  }
}

/// Payment Success Response
class PaymentSuccessResponse {
  final String paymentId;
  final String orderId;
  final String signature;

  PaymentSuccessResponse({
    required this.paymentId,
    required this.orderId,
    required this.signature,
  });

  factory PaymentSuccessResponse.fromJson(Map<String, dynamic> json) {
    return PaymentSuccessResponse(
      paymentId: json['payment_id'] as String,
      orderId: json['order_id'] as String,
      signature: json['signature'] as String,
    );
  }
}

/// Payment Failure Response
class PaymentFailureResponse {
  final int? code;
  final String message;

  PaymentFailureResponse({this.code, required this.message});
}
