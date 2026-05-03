import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'order_success_screen.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';

/// Clean Payment Screen - Minimal UI, No Address, No Wallet
class PaymentScreen extends StatefulWidget {
  final int total;
  final double subtotal;
  final double deliveryFee;
  final double gst;
  final String shopName;
  final String shopId;
  final String? vendorId;
  final List<Map<String, dynamic>> items;
  final double deliveryDistance;

  const PaymentScreen({
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
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  late Razorpay _razorpay;
  String _paymentOption = 'online'; // 'online' or 'cod'

  @override
  void initState() {
    super.initState();
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

  // ========== PAYMENT HANDLERS ==========

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      debugPrint('✅ Payment Success: ${response.paymentId}');
      
      final orderId = await _placeOrder(
        paymentId: response.paymentId,
        paymentStatus: 'paid',
      );

      _clearCartAndNavigate(orderId, 'Online');
    } catch (e) {
      debugPrint('Error saving order: $e');
      _showError('Payment successful but order failed. Contact support.');
      setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Payment Failed: ${response.message}');
    setState(() => _isProcessing = false);
    _showError('Payment Failed: ${response.message ?? 'Unknown error'}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet: ${response.walletName}");
  }

  // ========== ORDER PLACEMENT ==========

  Future<void> _handlePlaceOrder() async {
    if (_paymentOption == 'cod') {
      await _placeOrderCOD();
    } else {
      _openRazorpay();
    }
  }

  void _openRazorpay() {
    final int amountInPaise = widget.total * 100;
    
    var options = {
      'key': 'rzp_test_Sg5b2R2npEJeNx',
      'amount': amountInPaise,
      'name': 'Multiverse',
      'description': 'Order at ${widget.shopName}',
      'prefill': {
        'contact': FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
        'email': FirebaseAuth.instance.currentUser?.email ?? '',
      },
      'theme': {'color': '#FF4D4F'},
      'external': {'wallets': ['paytm']},
    };

    try {
      setState(() => _isProcessing = true);
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      _showError('Failed to open payment gateway');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _placeOrderCOD() async {
    setState(() => _isProcessing = true);

    try {
      final orderId = await _placeOrder(paymentStatus: 'pending_cod');
      _clearCartAndNavigate(orderId, 'COD');
    } catch (e) {
      debugPrint('Error placing COD order: $e');
      _showError('Failed to place order');
      setState(() => _isProcessing = false);
    }
  }

  Future<String> _placeOrder({String? paymentId, String? paymentStatus}) async {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    
    return await orderProvider.createOrder(
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      shopId: widget.shopId,
      vendorId: widget.vendorId,
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
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.clear();
    
    if (!mounted) return;
    
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

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Payment',
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
          ...widget.items.take(3).map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item['name']} ×${item['qty']}',
                      style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
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
          if (widget.items.length > 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '+ ${widget.items.length - 3} more items',
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const Divider(color: Color(0xFF333333), height: 24),
          _summaryRow('Subtotal', '₹${widget.subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _summaryRow('Delivery Fee', '₹${widget.deliveryFee.toStringAsFixed(0)}'),
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
          // Two big buttons
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
          const SizedBox(height: 16),
          // Trust badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: 0.7,
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF888888)),
                    const SizedBox(width: 4),
                    const Text(
                      'Secured by Razorpay',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Opacity(
                opacity: 0.7,
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF888888)),
                    const SizedBox(width: 4),
                    const Text(
                      '100% Safe Payments',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 11),
                    ),
                  ],
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
            color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFF333333),
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
