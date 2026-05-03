import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'order_success_screen.dart';
import 'saved_addresses_screen.dart';
import 'add_address_screen.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../services/settings_service.dart';

/// Custom Payment UI with Razorpay Backend
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
  final String? specialRequest;

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
    this.specialRequest,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  late Razorpay _razorpay;
  String _selectedPaymentMethod = ''; // 'gpay', 'phonepe', 'paytm', 'card', 'cod'
  
  // Address management
  final SettingsService _settingsService = SettingsService();
  Map<String, dynamic>? _selectedAddress;
  bool _isLoadingAddress = true;

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
    _loadDefaultAddress();
  }

  Future<void> _loadDefaultAddress() async {
    try {
      final address = await _settingsService.getDefaultAddress();
      if (mounted) {
        setState(() {
          _selectedAddress = address;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading address: $e');
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
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

  void _handlePlaceOrder() async {
    HapticFeedback.mediumImpact();
    
    if (_selectedAddress == null) {
      _showError('Please select delivery address');
      return;
    }

    if (_selectedPaymentMethod.isEmpty) {
      _showError('Please select a payment method');
      return;
    }

    if (_selectedPaymentMethod == 'cod') {
      await _placeOrderCOD();
    } else {
      _openRazorpay();
    }
  }

  void _openRazorpay() {
    final int amountInPaise = widget.total * 100;
    
    String methodLabel = 'Payment';
    if (_selectedPaymentMethod == 'gpay') {
      methodLabel = 'Google Pay';
    } else if (_selectedPaymentMethod == 'phonepe') {
      methodLabel = 'PhonePe';
    } else if (_selectedPaymentMethod == 'paytm') {
      methodLabel = 'Paytm';
    } else if (_selectedPaymentMethod == 'card') {
      methodLabel = 'Card Payment';
    }
    
    debugPrint('💳 Processing via $methodLabel');
    
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
      'external': {
        'wallets': _selectedPaymentMethod == 'paytm' ? ['paytm'] : [],
      },
    };

    try {
      setState(() => _isProcessing = true);
      _showProcessingSnackbar(methodLabel);
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      _showError('Failed to open payment gateway');
      setState(() => _isProcessing = false);
    }
  }

  void _showProcessingSnackbar(String method) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
            Text('Processing via $method...'),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
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
    
    String paymentMethodName = 'cod';
    if (_selectedPaymentMethod == 'gpay') {
      paymentMethodName = 'Google Pay';
    } else if (_selectedPaymentMethod == 'phonepe') {
      paymentMethodName = 'PhonePe';
    } else if (_selectedPaymentMethod == 'paytm') {
      paymentMethodName = 'Paytm';
    } else if (_selectedPaymentMethod == 'card') {
      paymentMethodName = 'Card';
    }
    
    return await orderProvider.createOrder(
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      shopId: widget.shopId,
      vendorId: widget.vendorId,
      items: widget.items,
      subtotal: widget.subtotal,
      deliveryFee: widget.deliveryFee,
      gst: widget.gst,
      total: widget.total.toDouble(),
      paymentMethod: paymentMethodName,
      paymentStatus: paymentStatus ?? 'pending',
      paymentId: paymentId,
      address: _selectedAddress,
      specialRequest: widget.specialRequest ?? '',
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

  // ========== ADDRESS SELECTION ==========

  Future<void> _selectAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SavedAddressesScreen(selectionMode: true),
      ),
    );

    if (result != null && mounted) {
      setState(() => _selectedAddress = result as Map<String, dynamic>);
    }
  }

  Future<void> _addNewAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddAddressScreen()),
    );

    if (result != null && mounted) {
      setState(() => _selectedAddress = result as Map<String, dynamic>);
    }
  }

  void _selectPaymentMethod(String method) {
    setState(() => _selectedPaymentMethod = method);
  }

  String _getButtonText() {
    if (_selectedPaymentMethod.isEmpty) {
      return 'Select Payment Method →';
    }
    
    String methodText = '';
    if (_selectedPaymentMethod == 'gpay') {
      methodText = 'Google Pay';
    } else if (_selectedPaymentMethod == 'phonepe') {
      methodText = 'PhonePe';
    } else if (_selectedPaymentMethod == 'paytm') {
      methodText = 'Paytm';
    } else if (_selectedPaymentMethod == 'card') {
      methodText = 'Card';
    } else if (_selectedPaymentMethod == 'cod') {
      methodText = 'Place Order - ';
    }
    
    final String amount = '₹${widget.total.toStringAsFixed(0)}';
    return _selectedPaymentMethod == 'cod' 
        ? '$methodText$amount →'
        : 'Pay via $methodText $amount →';
  }

  // ========== UI ==========

  Widget _buildAddressSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Delivery Address',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _isLoadingAddress
              ? Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
                  ),
                )
              : _selectedAddress == null
                  ? _buildNoAddressCard()
                  : _buildAddressCard(),
        ],
      ),
    );
  }

  Widget _buildNoAddressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 48,
            color: const Color(0xFF888888),
          ),
          const SizedBox(height: 12),
          const Text(
            'No saved addresses',
            style: TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addNewAddress,
              icon: const Icon(Icons.add_location, size: 20),
              label: const Text('Add Address'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D4F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    final name = _selectedAddress!['name'] ?? 'Name';
    final phone = _selectedAddress!['phone'] ?? '';
    final house = _selectedAddress!['house'] ?? '';
    final area = _selectedAddress!['area'] ?? '';
    final city = _selectedAddress!['city'] ?? '';
    final pincode = _selectedAddress!['pincode'] ?? '';
    
    final addressLine = [house, area, city, pincode]
        .where((s) => s.toString().isNotEmpty)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1E1E),
            const Color(0xFF252525),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF4D4F).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D4F).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4D4F), Color(0xFFFF6B6B)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivering to 📍',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _selectAddress,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D4F).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF4D4F), width: 1),
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(
                      color: Color(0xFFFF4D4F),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            addressLine,
            style: const TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '📞 $phone',
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

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
                  _buildAddressSection(),
                  const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1E1E).withValues(alpha: 0.95),
            const Color(0xFF252525).withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF4D4F).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Subtotal', '₹${widget.subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow('Delivery Fee', '₹${widget.deliveryFee.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow('GST (5%)', '₹${widget.gst.toStringAsFixed(2)}'),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Divider(color: Color(0xFF444444), thickness: 1.5),
          ),
          const SizedBox(height: 12),
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
                '₹${widget.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFFF4D4F),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFAAAAAA),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
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
          
          const Text(
            'Online Payment',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildCustomPaymentButton(
                  label: 'Google Pay',
                  icon: Icons.g_mobiledata_rounded,
                  color: const Color(0xFF4285F4),
                  isSelected: _selectedPaymentMethod == 'gpay',
                  onTap: () => _selectPaymentMethod('gpay'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCustomPaymentButton(
                  label: 'PhonePe',
                  icon: Icons.phone_android_rounded,
                  color: const Color(0xFF5F259F),
                  isSelected: _selectedPaymentMethod == 'phonepe',
                  onTap: () => _selectPaymentMethod('phonepe'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildCustomPaymentButton(
                  label: 'Paytm',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF00BAF2),
                  isSelected: _selectedPaymentMethod == 'paytm',
                  onTap: () => _selectPaymentMethod('paytm'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCustomPaymentButton(
                  label: 'Card',
                  icon: Icons.credit_card_rounded,
                  color: const Color(0xFFFF9800),
                  isSelected: _selectedPaymentMethod == 'card',
                  onTap: () => _selectPaymentMethod('card'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          const Text(
            'Cash on Delivery',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildCustomPaymentButton(
            label: 'Cash on Delivery',
            icon: Icons.payments_rounded,
            color: const Color(0xFF4CAF50),
            isSelected: _selectedPaymentMethod == 'cod',
            onTap: () => _selectPaymentMethod('cod'),
            fullWidth: true,
          ),
          const SizedBox(height: 16),
          
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

  Widget _buildCustomPaymentButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.translucent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF2A2A2A), Color(0xFF252525)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF444444),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFF333333),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFCCCCCC),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPayButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF111111),
            const Color(0xFF0D0D0D),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _isProcessing ? null : _handlePlaceOrder,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 60,
          decoration: BoxDecoration(
            gradient: _isProcessing
                ? const LinearGradient(
                    colors: [Color(0xFF999999), Color(0xFF888888)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFFFF4D4F), Color(0xFFD32F2F)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: _isProcessing
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFFFF4D4F).withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Center(
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getButtonText(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
