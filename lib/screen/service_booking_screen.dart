import 'dart:ui';
import 'dart:async';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/logging_service.dart';
import '../widgets/premium_ui_widgets.dart';
import '../utils/price_calculator.dart';
import '../services/fee_config_service.dart';
import '../models/coupon_model.dart';
import '../services/coupon_service.dart';

class ServiceBookingScreen extends StatefulWidget {
  final Map<String, dynamic> service;

  const ServiceBookingScreen({super.key, required this.service});

  @override
  State<ServiceBookingScreen> createState() => _ServiceBookingScreenState();
}

class _ServiceBookingScreenState extends State<ServiceBookingScreen> {
  Map<String, dynamic> _partnerSchedule = {};
  List<String> _availableTimeSlots = [];

  @override
  void initState() {
    super.initState();
    _partnerSchedule = widget.service["full_partner_data"]?["schedule"] ?? {};
    _updateSelectedDateAndSlots(DateTime.now());
    _feeSub = FeeConfigService.stream.listen((_) {
      if (mounted) setState(() {});
    });
    _loadCoupons();
  }

  StreamSubscription<Map<String, double>>? _feeSub;

  // ── Coupons ──
  final TextEditingController _couponController = TextEditingController();
  List<CouponModel> _vendorOffers = [];
  CouponModel? _appliedOffer;
  double _couponDiscount = 0;
  String? _appliedCouponCode;
  StreamSubscription? _couponSubscription;
  bool _couponLoading = true;

  String get _partnerId =>
      widget.service['full_partner_data']?['userId'] ?? widget.service['id'] ?? '';

  double get _basePrice => (widget.service['price'] ?? 499).toDouble();
  double get _bookingPrice =>
      _basePrice + PriceCalculator.FIXED_MARKUP;

  void _loadCoupons() {
    _couponSubscription?.cancel();
    _couponSubscription = CouponService.streamAllActive().listen(
      (snap) {
        final List<CouponModel> all = [];
        for (final doc in snap.docs) {
          final coupon = CouponModel.fromMap(doc.data(), doc.id);
          final code = coupon.code.toUpperCase();
          final vendorOk = coupon.vendorId.isEmpty ||
              coupon.vendorId == 'ADMIN' ||
              (_partnerId.isNotEmpty && coupon.vendorId == _partnerId);
          if (vendorOk &&
              coupon.matchesScope(CouponModel.scopeAppointment) &&
              !all.any((c) => c.code == code)) {
            all.add(coupon);
          }
        }
        if (mounted) {
          setState(() {
            _vendorOffers = all;
            _couponLoading = false;
          });
        }
      },
      onError: (Object e) {
        if (mounted) setState(() => _couponLoading = false);
      },
    );
  }

  void _applyCouponFromCard(CouponModel coupon) {
    if (coupon.code.isEmpty) return;
    final discount = coupon.calculateDiscount(_bookingPrice);
    if (discount <= 0) {
      _showSnack('Coupon not applicable on this booking');
      return;
    }
    if (coupon.id != null) CouponService.trackClick(coupon.id!);
    setState(() {
      _appliedOffer = coupon;
      _appliedCouponCode = coupon.code;
      _couponDiscount = discount;
      _couponController.clear();
    });
    _showSnack('Coupon ${coupon.code} applied!');
  }

  Future<void> _applyManualCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final matching = _vendorOffers.where((c) => c.code == code).toList();
    if (matching.isNotEmpty) {
      _applyCouponFromCard(matching.first);
      return;
    }
    setState(() => _couponLoading = true);
    try {
      final result = await CouponService.applyCoupon(
        code: code,
        vendorId: _partnerId.isEmpty ? 'ADMIN' : _partnerId,
        orderAmount: _bookingPrice,
        userId: FirebaseAuth.instance.currentUser?.uid,
        appliesTo: CouponModel.scopeAppointment,
      );
      if (!mounted) return;
      setState(() => _couponLoading = false);
      if (result.success && result.coupon != null) {
        if (result.coupon!.id != null) {
          CouponService.trackClick(result.coupon!.id!);
        }
        _applyCouponFromCard(result.coupon!);
      } else {
        _showSnack(result.error ?? 'Invalid coupon code');
      }
    } catch (e) {
      Log.e('ServiceBookingScreen', 'Error applying coupon: $e');
      if (mounted) setState(() => _couponLoading = false);
      _showSnack('Invalid coupon code');
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedOffer = null;
      _appliedCouponCode = null;
      _couponDiscount = 0;
    });
    _showSnack('Coupon removed');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _feeSub?.cancel();
    _couponSubscription?.cancel();
    _couponController.dispose();
    super.dispose();
  }

  void _updateSelectedDateAndSlots(DateTime date) {
    setState(() {
      _selectedDate = date;
      final dateKey =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      _availableTimeSlots = List<String>.from(_partnerSchedule[dateKey] ?? []);

      if (_availableTimeSlots.isNotEmpty) {
        _selectedTime = _availableTimeSlots[0];
      } else {
        _selectedTime = "";
      }
    });
  }

  DateTime _selectedDate = DateTime.now();
  String _selectedTime = '10:00 AM';
  bool _isProcessing = false;

  void _handleBooking() async {
    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final double basePrice = (widget.service['price'] ?? 499).toDouble();
      final breakdown = PriceCalculator.calculateBookingPrice(basePrice);
      final totalPayable =
          ((breakdown['totalPayable'] as double) - _couponDiscount)
              .clamp(0, double.infinity);

      if (user != null) {
        await FirebaseFirestore.instance.collection('service_requests').add({
          'userId': user.uid,
          'serviceType': widget.service['name'],
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'bookingDate':
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
          'bookingTime': _selectedTime,
          'basePrice': breakdown['basePrice'],
          'markup': breakdown['markup'],
          'platformFee': breakdown['platformFee'],
          'gst': breakdown['gst'],
          'couponCode': _appliedCouponCode,
          'couponDiscount': _couponDiscount,
          'totalPrice': totalPayable,
          'profit': breakdown['profit'],
        });
        if (_appliedOffer?.id != null) {
          await CouponService.recordUsage(_appliedOffer!.id!, user.uid);
        }
      }
    } catch (e) {
      Log.e('ServiceBookingScreen', 'Error saving service request: $e');
    }

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    _showSuccessDialog();
    setState(() => _isProcessing = false);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(30),
            borderRadius: 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.greenAccent,
                  size: 80,
                ),
                const SizedBox(height: 20),
                Text(
                  'BOOKING CONFIRMED',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 25),
                _infoRow('SERVICE', widget.service['name']),
                _infoRow(
                  'DATE',
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                ),
                _infoRow('TIME', _selectedTime),
                const SizedBox(height: 30),
                Text(
                  'A service professional will be assigned soon.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 40),
                NeonButton(
                  text: 'DONE',
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back from booking
                    Navigator.pop(context); // Go back from detail
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.orbitron(color: Colors.white38, fontSize: 10),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color themeColor = widget.service['color'] ?? const Color(0xFFFF7A1A);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'BOOK SERVICE',
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              children: [
                Text(
                  'SELECT DATE',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 15),
                _buildDatePicker(themeColor),

                const SizedBox(height: 40),

                Text(
                  'SELECT TIME SLOT',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _availableTimeSlots.map((time) {
                    bool isSelected = _selectedTime == time;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTime = time),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? themeColor
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.white10,
                          ),
                        ),
                        child: Text(
                          time,
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 40),

                _buildCouponSection(themeColor),

                const SizedBox(height: 40),

                GlassCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 20,
                  opacity: 0.05,
                  child: Builder(
                    builder: (context) {
                      final double basePrice = (widget.service['price'] ?? 499)
                          .toDouble();
                      final breakdown = PriceCalculator.calculateBookingPrice(
                        basePrice,
                      );
                      final totalPayable =
                          ((breakdown['totalPayable'] as double) -
                                  _couponDiscount)
                              .clamp(0, double.infinity);
                      return Column(
                        children: [
                          _priceRow(
                            'Booking Price',
                            '₹ ${(breakdown['basePrice'] + breakdown['markup']).toStringAsFixed(0)}',
                          ),
                          _priceRow(
                            'Platform Fee',
                            '₹ ${breakdown['platformFee'].toStringAsFixed(0)}',
                          ),
                          _priceRow(
                            'GST (18%)',
                            '₹ ${breakdown['gst'].toStringAsFixed(2)}',
                          ),
                          if (_couponDiscount > 0) ...[
                            const Divider(color: Colors.white10, height: 30),
                            _priceRow(
                              'Coupon Discount (${_appliedCouponCode ?? ''})',
                              '-₹ ${_couponDiscount.toStringAsFixed(0)}',
                              discount: true,
                            ),
                          ],
                          const Divider(color: Colors.white10, height: 30),
                          _priceRow(
                            'Total Amount',
                            '₹ ${totalPayable.toStringAsFixed(2)}',
                            isTotal: true,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: _isProcessing
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF7A1A)),
                  )
                : NeonButton(
                    text: 'CONFIRM BOOKING',
                    onPressed: _handleBooking,
                    glowColor: themeColor,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(Color themeColor) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        itemBuilder: (context, index) {
          DateTime date = DateTime.now().add(Duration(days: index));
          bool isSelected =
              _selectedDate.day == date.day &&
              _selectedDate.month == date.month;

          return GestureDetector(
            onTap: () => _updateSelectedDateAndSlots(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 70,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? themeColor
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white10,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getMonthName(date.month),
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white70 : Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: GoogleFonts.orbitron(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[month - 1];
  }

  Widget _priceRow(
    String label,
    String value, {
    bool isTotal = false,
    bool discount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isTotal ? Colors.white : Colors.white54,
              fontSize: isTotal ? 14 : 13,
            ),
          ),
          Text(
            value,
            style: isTotal
                ? GoogleFonts.orbitron(
                    color: const Color(0xFFFF7A1A),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  )
                : discount
                ? GoogleFonts.poppins(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  )
                : GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection(Color themeColor) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      opacity: 0.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined, color: themeColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'COUPONS',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponController,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter coupon code',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: themeColor.withValues(alpha: 0.4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: themeColor.withValues(alpha: 0.4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: themeColor, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _applyManualCoupon(),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _couponLoading ? null : _applyManualCoupon,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: _couponLoading
                        ? themeColor.withValues(alpha: 0.3)
                        : themeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _couponLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'APPLY',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_appliedCouponCode != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Code $_appliedCouponCode applied',
                      style: GoogleFonts.poppins(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _removeCoupon,
                    child: Text(
                      'REMOVE',
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_vendorOffers.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _vendorOffers.length,
                itemBuilder: (context, index) =>
                    _buildCouponCard(_vendorOffers[index], themeColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCouponCard(CouponModel coupon, Color themeColor) {
    final isApplied = _appliedCouponCode == coupon.code;
    final canApply = _bookingPrice >= coupon.minOrderValue;
    final deficit = coupon.minOrderValue - _bookingPrice;

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isApplied
            ? const LinearGradient(
                colors: [Color(0xFF43A047), Color(0xFF8BC34A)],
              )
            : const LinearGradient(
                colors: [Color(0xFF1A1A24), Color(0xFF14141C)],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApplied
              ? const Color(0xFF4CAF50)
              : themeColor.withValues(alpha: 0.4),
          width: isApplied ? 2 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.confirmation_num, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  coupon.title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  coupon.appliesToLabel,
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              coupon.discountLabel,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 5),
          if (coupon.description.isNotEmpty)
            Text(
              coupon.description,
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (coupon.minOrderValue > 0)
            Text(
              'Min booking ₹${coupon.minOrderValue.toStringAsFixed(0)}',
              style: const TextStyle(color: Color(0xFF888888), fontSize: 8),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const Spacer(),
          if (!isApplied)
            GestureDetector(
              onTap: canApply
                  ? () => _applyCouponFromCard(coupon)
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: canApply
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  canApply ? 'APPLY' : 'ADD ₹${deficit.toInt()} MORE',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: canApply ? Colors.black : Colors.white38,
                    fontWeight: FontWeight.w800,
                    fontSize: canApply ? 11 : 9,
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '✓ APPLIED',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
