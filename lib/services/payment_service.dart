// 📁 lib/services/payment_service.dart

import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentService {
  late Razorpay _razorpay;

  void init({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onFailure);
  }

  void openPayment({required int amountInRupees, required String orderId}) {
    final options = {
      'key': 'YOUR_RAZORPAY_KEY', // 👈 Add your key from razorpay.com
      'amount': amountInRupees * 100, // Razorpay needs paise
      'name': 'Multiverse',
      'description': 'Order #$orderId',
      'prefill': {'contact': '9876543210', 'email': 'user@email.com'},
    };
    _razorpay.open(options);
  }

  void dispose() => _razorpay.clear();
}
