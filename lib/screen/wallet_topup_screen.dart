import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:http/http.dart' as http;

import '../services/wallet_service.dart';
import '../services/payment_service.dart';
import '../services/runtime_config_service.dart';
import '../widgets/premium_ui_widgets.dart';
import '../core/logging_service.dart';
import '../core/app_constants.dart';

class WalletTopupScreen extends StatefulWidget {
  const WalletTopupScreen({super.key});

  @override
  State<WalletTopupScreen> createState() => _WalletTopupScreenState();
}

class _WalletTopupScreenState extends State<WalletTopupScreen> {
  final WalletService _walletService = WalletService();
  final PaymentService _paymentService = PaymentService();

  final List<double> _presetAmounts = [100, 200, 500, 1000, 2000];
  double? _selectedAmount;
  final _customAmountController = TextEditingController();

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  void _initializePayment() {
    _paymentService.init(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentError,
      onExternalWallet: _handleExternalWallet,
    );
  }

  @override
  void dispose() {
    _paymentService.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF08080B),
        body: Center(child: Text('Please login first')),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF08080B),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF07070A), Color(0xFF121218), Color(0xFF1A1220)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWalletBalanceCard(user.uid),
                      const SizedBox(height: 24),
                      _buildQuickAmounts(),
                      const SizedBox(height: 24),
                      _buildCustomAmount(),
                      const SizedBox(height: 32),
                      _buildProceedButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF15151A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Money',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Top up your wallet instantly',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletBalanceCard(String userId) {
    return StreamBuilder<double>(
      stream: _walletService.getBalanceStream(userId),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0.0;
        return GlassCard(
          borderRadius: 30,
          borderColor: const Color(0x22FF6A3D),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      '₹',
                      style: TextStyle(
                        color: Color(0xFFFF6A3D),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      tween: Tween<double>(begin: 0, end: balance),
                      builder: (context, value, child) {
                        return Text(
                          value.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF6A3D),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAmounts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Amounts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _presetAmounts.map((amount) {
            final isSelected = _selectedAmount == amount;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedAmount = amount;
                  _customAmountController.clear();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFFFF6A3D), Color(0xFFFF8B5E)],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF6A3D)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFFF6A3D,
                            ).withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '₹${amount.toInt()}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomAmount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Custom Amount',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _customAmountController,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() {
              _selectedAmount = null;
            });
          },
          decoration: InputDecoration(
            hintText: 'Enter amount',
            prefixText: '₹ ',
            prefixStyle: const TextStyle(
              color: Color(0xFFFF6A3D),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFFF6A3D), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProceedButton() {
    final amount = _getSelectedAmount();
    final isEnabled = amount != null && amount > 0 && !_isProcessing;

    return GestureDetector(
      onTap: isEnabled ? _proceedToPayment : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(
                  colors: [Color(0xFFFF6A3D), Color(0xFFFF8B5E)],
                )
              : null,
          color: isEnabled ? null : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isEnabled
              ? [
                  const BoxShadow(
                    color: Color(0x66FF6A3D),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: _isProcessing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isEnabled ? 'Pay ₹${amount.toInt()}' : 'Enter Amount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    );
  }

  double? _getSelectedAmount() {
    if (_selectedAmount != null) return _selectedAmount;
    final customText = _customAmountController.text.trim();
    if (customText.isEmpty) return null;
    return double.tryParse(customText);
  }

  Future<void> _proceedToPayment() async {
    final amount = _getSelectedAmount();
    if (amount == null || amount <= 0) return;

    // Runtime wallet limits from admin Dynamic Configuration -> Wallet Settings.
    final config = RuntimeConfigService.instance;
    if (amount < config.walletMinAdd) {
      _showError('Minimum add amount is ₹${config.walletMinAdd.toInt()}');
      return;
    }
    if (amount > config.walletMaxAdd) {
      _showError('Maximum add amount is ₹${config.walletMaxAdd.toInt()}');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isProcessing = true;
    });

    HapticFeedback.mediumImpact();

    try {
      Log.p('WalletTopupScreen', '[Wallet] Starting server-side order creation: ₹$amount');

      // 1. Create Order on Server (to get real razorpayOrderId)
      final String url = CloudFunctions.createRazorpayOrder;

      final response = await http
          .post(
            Uri.parse(url),
            headers: await CloudFunctions.authHeaders(),
            body: jsonEncode({
              'data': {
                'amount': (amount * 100).toInt(),
                'receipt':
                    'wallet_topup_${DateTime.now().millisecondsSinceEpoch}',
                'uid': user.uid,
              },
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Failed to create order (${response.statusCode})');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final String? razorpayOrderId = responseData['data']?['order_id'];

      if (razorpayOrderId == null) {
        throw Exception('Failed to get order_id from server');
      }

      Log.i('WalletTopupScreen', '[Wallet] Order created: $razorpayOrderId');

      // 2. Open Razorpay Payment UI
      _paymentService.openPayment(
        amountInRupees: amount.toInt(),
        razorpayOrderId: razorpayOrderId,
        description: 'Wallet Topup - ₹${amount.toInt()}',
        contact: user.phoneNumber ?? '',
        email: user.email ?? '',
      );
    } catch (e) {
      Log.e('WalletTopupScreen', '[Wallet] Error: $e');
      setState(() {
        _isProcessing = false;
      });
      _showError('Failed to initialize payment: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final user = FirebaseAuth.instance.currentUser;
    final amount = _getSelectedAmount();

    if (user == null || amount == null) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      Log.i('WalletTopupScreen', '[Wallet] Payment successful, verifying signature...');

      // 1. Verify Payment Signature via Server
      final String url = CloudFunctions.verifyRazorpayPayment;

      final verifyResponse = await http
          .post(
            Uri.parse(url),
            headers: await CloudFunctions.authHeaders(),
            body: jsonEncode({
              'data': {
                'razorpay_payment_id': response.paymentId,
                'razorpay_order_id': response.orderId,
                'razorpay_signature': response.signature,
                'uid': user.uid,
              },
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (verifyResponse.statusCode != 200) {
        throw Exception('Verification failed');
      }

      final Map<String, dynamic> result = jsonDecode(verifyResponse.body);
      if (result['data']?['success'] != true) {
        throw Exception(
          result['data']?['message'] ?? 'Payment verification failed',
        );
      }

      Log.i('WalletTopupScreen', '[Wallet] Signature verified. Crediting wallet...');

      // 2. Credit wallet using verified payment
      await _walletService.creditWallet(
        userId: user.uid,
        amount: amount,
        source: 'razorpay',
        paymentId: response.paymentId ?? '',
        description: 'Wallet topup via Razorpay',
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showSuccessAnimation(amount);
      }
    } catch (e) {
      Log.e('WalletTopupScreen', '[Wallet] Error in success handler: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _showError(
          'Payment successful but verification failed. Contact support.',
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _isProcessing = false;
    });
    HapticFeedback.heavyImpact();
    _showError('Payment failed: ${response.message}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Log.i('WalletTopupScreen', 'External wallet: ${response.walletName}');
  }

  void _showSuccessAnimation(double amount) {
    HapticFeedback.lightImpact();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF15151A),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0x44FF6A3D)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Success!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${amount.toInt()} added to wallet',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
