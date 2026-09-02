import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'order_success_screen.dart';
import 'payment_processing_screen.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';

/// DEBUG VERSION - Payment Screen with Logging
import '../core/logging_service.dart';
import '../services/runtime_api_keys.dart';

class PaymentScreenDebug extends StatefulWidget {
  final int total;
  final double subtotal;
  final double deliveryFee;
  final double gst;
  final String shopName;
  final String shopId;
  final String? vendorId;
  final List<Map<String, dynamic>> items;
  final double deliveryDistance;

  const PaymentScreenDebug({
    super.key,
    required this.total,
    required this.subtotal,
    required this.deliveryFee,
    required this.gst,
    required this.shopName,
    required this.shopId,
    this.vendorId,
    required this.items,
    this.deliveryDistance = 0,
  });

  @override
  State<PaymentScreenDebug> createState() => _PaymentScreenDebugState();
}

class _PaymentScreenDebugState extends State<PaymentScreenDebug> {
  bool _isProcessing = false;
  late Razorpay _razorpay;
  String _paymentOption = 'online';

  @override
  void initState() {
    super.initState();
    Log.i('PaymentDebugScreen', '🎯 [DEBUG] PaymentScreen initialized');
    _initializeRazorpay();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    Log.i('PaymentDebugScreen', '✅ [DEBUG] ===== PAYMENT SUCCESS =====');
    Log.i('PaymentDebugScreen', '✅ [DEBUG] Payment ID: ${response.paymentId}');
    Log.i('PaymentDebugScreen', '🔄 [DEBUG] Navigating to PaymentProcessingScreen...');

    if (!mounted) {
      Log.e('PaymentDebugScreen', 'Widget not mounted!');
      return;
    }

    Log.i('PaymentDebugScreen', '🚀 [DEBUG] Calling Navigator.push...');

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          Log.i('PaymentDebugScreen', '✅ [DEBUG] PaymentProcessingScreen BUILDER CALLED!');
          return PaymentProcessingScreen(
            total: widget.total.toDouble(),
            shopName: widget.shopName,
            paymentMethod: 'ONLINE',
            onCancel: () {
              Log.e('PaymentDebugScreen', 'CANCEL TAPPED');
              Navigator.pop(context);
              setState(() => _isProcessing = false);
            },
            onComplete: () async {
              Log.i('PaymentDebugScreen', '✅ [DEBUG] ===== ON COMPLETE CALLED =====');
              Log.i('PaymentDebugScreen', '📝 [DEBUG] Creating order...');

              try {
                final orderId = await _placeOrder(
                  paymentId: response.paymentId,
                  paymentStatus: 'paid',
                );

                Log.i('PaymentDebugScreen', '✅ [DEBUG] Order created: $orderId');

                if (!mounted) return;
                Log.i(
                  'PaymentDebugScreen', '🚀 [DEBUG] Clearing cart and navigating to success...',
                );
                _clearCartAndNavigate(orderId, 'Online');
              } catch (e) {
                  Log.e('PaymentDebugScreen', 'Error: $e');
                _showError('Payment successful but order failed.');
                Navigator.pop(context);
                setState(() => _isProcessing = false);
              }
            },
          );
        },
      ),
    );

    Log.i('PaymentDebugScreen', '📍 [DEBUG] Navigator.push completed');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    Log.e('PaymentDebugScreen', 'Payment Failed: ${response.message}');
    setState(() => _isProcessing = false);
    _showError('Payment Failed: ${response.message ?? 'Unknown error'}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Log.i('PaymentDebugScreen', "🔵 [DEBUG] External Wallet: ${response.walletName}");
  }

  Future<void> _handlePlaceOrder() async {
    Log.i('PaymentDebugScreen', '👆 [DEBUG] Place Order tapped - Option: $_paymentOption');
    if (_paymentOption == 'cod') {
      await _placeOrderCOD();
    } else {
      _openRazorpay();
    }
  }

  void _openRazorpay() {
    Log.p('PaymentDebugScreen', '[DEBUG] Opening Razorpay...');
    final int amountInPaise = widget.total * 100;

    var options = {
      'key': RuntimeApiKeys.razorpayKeyId,
      'amount': amountInPaise,
      'name': 'Multiverse City',
      'description': 'Order at ${widget.shopName}',
      'prefill': {
        'contact': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
      },
      'theme': {'color': '#FF4D4F'},
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      setState(() => _isProcessing = true);
      _razorpay.open(options);
    } catch (e) {
      Log.e('PaymentDebugScreen', 'Error opening Razorpay: $e');
      _showError('Failed to open payment gateway');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _placeOrderCOD() async {
    Log.i('PaymentDebugScreen', '📦 [DEBUG] ===== COD ORDER STARTED =====');
    setState(() => _isProcessing = true);

    try {
      if (!mounted) {
        Log.e('PaymentDebugScreen', 'Widget not mounted for COD');
        return;
      }

      Log.i('PaymentDebugScreen', '🚀 [DEBUG] Navigating to PaymentProcessingScreen for COD...');

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            Log.i(
              'PaymentDebugScreen',
              '✅ [DEBUG] PaymentProcessingScreen BUILDER CALLED FOR COD!',
            );
            return PaymentProcessingScreen(
              total: widget.total.toDouble(),
              shopName: widget.shopName,
              paymentMethod: 'COD',
              onCancel: () {
                Log.e('PaymentDebugScreen', 'COD CANCEL TAPPED');
                Navigator.pop(context);
                setState(() => _isProcessing = false);
              },
              onComplete: () async {
                Log.i('PaymentDebugScreen', '✅ [DEBUG] ===== COD ON COMPLETE =====');
                try {
                  Log.i('PaymentDebugScreen', '📝 [DEBUG] Creating COD order...');
                  final orderId = await _placeOrder(
                    paymentStatus: 'pending_cod',
                  );
                  Log.i('PaymentDebugScreen', '✅ [DEBUG] COD Order created: $orderId');

                  if (!mounted) return;
                  Log.i('PaymentDebugScreen', '🚀 [DEBUG] Navigating to COD success...');
                  _clearCartAndNavigate(orderId, 'COD');
                } catch (e) {
                Log.e('PaymentDebugScreen', 'Error: $e');
                  _showError('Failed to place order');
                  Navigator.pop(context);
                  setState(() => _isProcessing = false);
                }
              },
            );
          },
        ),
      );

      Log.i('PaymentDebugScreen', '📍 [DEBUG] COD Navigator.push completed');
    } catch (e) {
      Log.e('PaymentDebugScreen', 'Error in COD flow: $e');
      _showError('Failed to place order');
      setState(() => _isProcessing = false);
    }
  }

  Future<String> _placeOrder({String? paymentId, String? paymentStatus}) async {
    Log.i(
      'PaymentDebugScreen',
      '📝 [DEBUG] _placeOrder called with paymentStatus: $paymentStatus',
    );
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    return await orderProvider.createOrder(
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      shopId: widget.shopId,
      vendorId: widget.vendorId,
      shopName: widget.shopName,
      items: widget.items,
      subtotal: widget.subtotal,
      deliveryFee: widget.deliveryFee,
      gst: widget.gst,
      total: widget.total.toDouble(),
      paymentMethod: _paymentOption == 'online' ? 'razorpay' : 'cod',
      paymentStatus: paymentStatus ?? 'pending',
      paymentId: paymentId,
    );
  }

  void _clearCartAndNavigate(String orderId, String paymentMethod) {
    Log.i('PaymentDebugScreen', '🗑️ [DEBUG] Clearing cart...');
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.clear();

    if (!mounted) return;

    Log.i('PaymentDebugScreen', '🚀 [DEBUG] Navigating to OrderSuccessScreen...');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          orderId: orderId,
          paymentMethod: paymentMethod,
          total: widget.total,
          shopName: widget.shopName,
        ),
      ),
      (route) => false,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _selectPaymentOption(String option) {
    HapticFeedback.lightImpact();
    setState(() => _paymentOption = option);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Payment (DEBUG)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildOrderSummary(),
                  const SizedBox(height: 24),
                  _buildPaymentButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildPayButton(),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...widget.items
              .take(3)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item['name']} ×${item['qty']}',
                          style: const TextStyle(
                            color: Color(0xFFAAAAAA),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '₹${((item['price'] ?? 0) * (item['qty'] ?? 1)).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const Divider(color: Color(0xFF333333), height: 24),
          _summaryRow('Subtotal', '₹${widget.subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _summaryRow(
            'Delivery Fee',
            '₹${widget.deliveryFee.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),
          _summaryRow('GST (18%)', '₹${widget.gst.toStringAsFixed(0)}'),
          const Divider(color: Color(0xFF333333), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${widget.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFFFF4D4F),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Method',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPaymentOption(
                  label: 'Pay Online',
                  subtitle: 'UPI • Card • Net Banking',
                  icon: Icons.bolt_rounded,
                  isSelected: _paymentOption == 'online',
                  onTap: () => _selectPaymentOption('online'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPaymentOption(
                  label: 'Cash on Delivery',
                  subtitle: 'Pay when delivered',
                  icon: Icons.payments_rounded,
                  isSelected: _paymentOption == 'cod',
                  onTap: () => _selectPaymentOption('cod'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF4D4F)
                : const Color(0xFF333333),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.white : const Color(0xFF888888),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFCCCCCC),
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.85)
                    : const Color(0xFF888888),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      color: const Color(0xFF111111),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isProcessing ? null : _handlePlaceOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4D4F),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'Pay ₹${widget.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
