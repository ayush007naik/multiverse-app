import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'booking_success_screen.dart';
import 'add_address_screen.dart';
import 'premium_payment_screen.dart';
import '../models/payment_method.dart';
import '../services/settings_service.dart';

import '../core/logging_service.dart';

class EnhancedFinalConfirmationScreen extends StatefulWidget {
  final String providerName;
  final double providerRating;
  final int finalPrice;
  final String arrivalTime;
  final String selectedTime;

  const EnhancedFinalConfirmationScreen({
    super.key,
    required this.providerName,
    required this.providerRating,
    required this.finalPrice,
    required this.arrivalTime,
    required this.selectedTime,
  });

  @override
  State<EnhancedFinalConfirmationScreen> createState() =>
      _EnhancedFinalConfirmationScreenState();
}

class _EnhancedFinalConfirmationScreenState
    extends State<EnhancedFinalConfirmationScreen> {
  int _selectedAddressIndex = 0;
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _savedAddresses = [
    {
      'type': 'Home',
      'icon': Icons.home_rounded,
      'address': '123, Main Street, City Center\nNear Central Mall, Floor 4',
      'city': 'Mumbai - 400001',
    },
    {
      'type': 'Office',
      'icon': Icons.business_rounded,
      'address': '456, Business Park, Andheri East\nTech Tower, 3rd Floor',
      'city': 'Mumbai - 400069',
    },
    {
      'type': 'Other',
      'icon': Icons.location_on_rounded,
      'address': '789, Linking Road, Bandra West\nOpposite Shopping Complex',
      'city': 'Mumbai - 400050',
    },
  ];

  IconData _getAddressIcon(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'office':
        return Icons.business_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _addNewAddress() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddAddressScreen(
          onSave: (address) async {
            await SettingsService().addAddress(address);
            return address; // Return the address
          },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _savedAddresses.add({
          'type': result['type']!,
          'icon': _getAddressIcon(result['type']!),
          'address': result['fullAddress']!,
          'city': '${result['city']} - ${result['pincode']}',
        });
        _selectedAddressIndex = _savedAddresses.length - 1;
      });
    }
  }

  // ========== PAYMENT FLOW ==========

  void _handlePayment() async {
    Log.i('FinalConfirmationScreen', '🔵 Button clicked - Proceed to Payment');

    // Validate booking data first
    if (_selectedAddressIndex < 0 ||
        _selectedAddressIndex >= _savedAddresses.length) {
      Log.e('FinalConfirmationScreen', 'Validation failed: No address selected');
      _showValidationError('Please select a valid address.');
      return;
    }

    Log.i('FinalConfirmationScreen', '✅ Validation passed');

    setState(() => _isProcessing = true);

    try {
      final total = widget.finalPrice + (widget.finalPrice * 0.18).round() + 49;

      Log.i('FinalConfirmationScreen', '💰 Amount: ₹$total');

      final user = FirebaseAuth.instance.currentUser;
      final PaymentResult? result = await Navigator.push<PaymentResult>(
        context,
        MaterialPageRoute(
          builder: (_) => PremiumPaymentScreen(
            total: total.toDouble(),
            shopName: 'Multiverse City',
            description: 'Service Booking - ${widget.providerName}',
            customerPhone: user?.phoneNumber,
            customerEmail: user?.email,
            showCod: false,
          ),
        ),
      );

      if (!mounted) return;

      if (result == null || !result.success) {
        setState(() => _isProcessing = false);
        _showPaymentFailedDialog(result?.message ?? 'Payment cancelled');
        return;
      }

      Log.i('FinalConfirmationScreen', '✅ Payment Success: ${result.paymentId}');

      // Payment successful, navigate to success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookingSuccessScreen(
            providerName: widget.providerName,
            providerRating: widget.providerRating,
            arrivalTime: widget.arrivalTime,
            totalAmount: total,
          ),
        ),
      );
    } catch (e) {
      Log.e('FinalConfirmationScreen', 'Error opening payment screen: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showPaymentFailedDialog('Failed to open payment gateway: $e');
      }
    }
  }

  void _showValidationError(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Validation Error',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A1A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.orbitron(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentFailedDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.payment_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Payment Failed',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Payment Failed. Please try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              if (errorMessage.isNotEmpty &&
                  errorMessage != 'Payment failed. Please try again.') ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.red.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Retry Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handlePayment(); // Retry payment
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF7A1A)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'RETRY',
                        style: GoogleFonts.orbitron(
                          color: const Color(0xFFFF7A1A),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Cancel Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'CANCEL',
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gst = (widget.finalPrice * 0.18).round();
    const platformFee = 49;
    final total = widget.finalPrice + gst + platformFee;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'CONFIRM FINAL BOOKING',
          style: GoogleFonts.orbitron(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              children: [
                // Price Breakdown Card
                _buildPriceCard(widget.finalPrice, gst, platformFee, total),

                const SizedBox(height: 20),

                // Service Details Card
                _buildServiceDetailsCard(),

                const SizedBox(height: 20),

                // Address Section
                _buildAddressSection(),

                const SizedBox(height: 20),

                // Payment Hold Info
                _buildPaymentHoldInfo(),

                const SizedBox(height: 30),
              ],
            ),
          ),

          // Proceed to Payment Button
          _buildPaymentButton(total),
        ],
      ),
    );
  }

  Widget _buildPriceCard(int serviceFee, int gst, int platformFee, int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildDetailRow('Service Fee', '₹$serviceFee'),
          const SizedBox(height: 10),
          _buildDetailRow('GST (18%)', '₹$gst'),
          const SizedBox(height: 10),
          _buildDetailRow('Platform Fee', '₹$platformFee'),
          const Divider(color: Colors.white10, height: 24),
          _buildDetailRow('Total Amount', '₹$total', isTotal: true),
        ],
      ),
    );
  }

  Widget _buildServiceDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Provider Info
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF7A1A), Color(0xFFFF5722)],
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.providerName[0],
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.providerName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.providerRating}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // Service Details
          _buildInfoRow(
            Icons.access_time_rounded,
            'Estimated Arrival',
            widget.arrivalTime,
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.calendar_today_rounded, 'Service Date', 'Today'),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.schedule_rounded,
            'Selected Time',
            widget.selectedTime,
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SERVICE ADDRESS',
              style: GoogleFonts.orbitron(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            TextButton(
              onPressed: _addNewAddress,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Add New',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFF7A1A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Address List
        ...List.generate(_savedAddresses.length, (index) {
          final address = _savedAddresses[index];
          final isSelected = _selectedAddressIndex == index;

          return GestureDetector(
            onTap: () => setState(() => _selectedAddressIndex = index),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF7A1A).withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF7A1A)
                      : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF7A1A).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      address['icon'] as IconData,
                      color: isSelected
                          ? const Color(0xFFFF7A1A)
                          : Colors.white.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              address['type'] as String,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF7A1A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Selected',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address['address'] as String,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          address['city'] as String,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < _savedAddresses.length - 1) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        // TODO: Open change address flow
                      },
                      child: Text(
                        'Change',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPaymentHoldInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.blueAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Payment',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Payment will be released to provider after successful service completion.',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton(int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF0A0A0D).withValues(alpha: 0.95),
            const Color(0xFF0A0A0D),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total to Pay',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              Text(
                '₹$total',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFFFF7A1A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isProcessing
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFFFF7A1A).withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
            ),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isProcessing
                    ? Colors.grey.withValues(alpha: 0.3)
                    : const Color(0xFFFF7A1A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
              ),
              child: _isProcessing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'OPENING PAYMENT...',
                          style: GoogleFonts.orbitron(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'PROCEED TO PAYMENT',
                      style: GoogleFonts.orbitron(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 12, color: Colors.white38),
              const SizedBox(width: 4),
              Text(
                'Payment secured by Razorpay',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: isTotal ? Colors.white : Colors.white.withValues(alpha: 0.6),
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: isTotal
              ? GoogleFonts.orbitron(
                  color: const Color(0xFFFF7A1A),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                )
              : GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF7A1A), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
