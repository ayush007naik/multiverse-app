import 'package:firebase_auth/firebase_auth.dart';
import 'package:db_compat/db_compat.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'appointment_success_screen.dart';
import 'premium_payment_screen.dart';
import '../models/payment_method.dart';
import '../utils/price_calculator.dart';
import '../services/fee_config_service.dart';
import '../models/coupon_model.dart';
import '../services/coupon_service.dart';
import '../core/logging_service.dart';

class ServiceDetailScreenV2 extends StatefulWidget {
  final Map<String, dynamic> service;
  final String category;
  const ServiceDetailScreenV2({
    super.key,
    required this.service,
    required this.category,
  });

  @override
  State<ServiceDetailScreenV2> createState() => _ServiceDetailScreenV2State();
}

class _ServiceDetailScreenV2State extends State<ServiceDetailScreenV2> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _problemController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedTime = '';
  Map<String, dynamic> _partnerSchedule = {};
  List<String> _availableTimeSlots = [];
  List<String> _bookedTimeSlots = [];
  bool _isLoadingSlots = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final partnerData = widget.service['full_partner_data'] ?? {};
    _partnerSchedule = Map<String, dynamic>.from(partnerData['schedule'] ?? {});
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

  double get _bookingPrice =>
      (widget.service['fee'] ?? 0).toDouble() + PriceCalculator.FIXED_MARKUP;

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
      _showCouponSnack('Coupon not applicable on this booking');
      return;
    }
    if (coupon.id != null) CouponService.trackClick(coupon.id!);
    setState(() {
      _appliedOffer = coupon;
      _appliedCouponCode = coupon.code;
      _couponDiscount = discount;
      _couponController.clear();
    });
    _showCouponSnack('Coupon ${coupon.code} applied!');
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
        _showCouponSnack(result.error ?? 'Invalid coupon code');
      }
    } catch (e) {
      Log.e('ServiceDetailScreenV2', 'Error applying coupon: $e');
      if (mounted) setState(() => _couponLoading = false);
      _showCouponSnack('Invalid coupon code');
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedOffer = null;
      _appliedCouponCode = null;
      _couponDiscount = 0;
    });
    _showCouponSnack('Coupon removed');
  }

  void _showCouponSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF08090D),
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

  void _updateSelectedDateAndSlots(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _isLoadingSlots = true;
      _selectedTime = '';
    });

    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final String partnerId =
        widget.service['full_partner_data']?['userId'] ??
        widget.service['id'] ??
        '';

    // 1. Get available slots from schedule
    List<String> available = List<String>.from(_partnerSchedule[dateKey] ?? []);

    // 2. Fetch existing bookings for this partner and date
    List<String> booked = [];
    try {
      final bookingsQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('partnerId', isEqualTo: partnerId)
          .where('bookingDate', isEqualTo: dateKey)
          .where('status', isNotEqualTo: 'cancelled')
          .get();

      booked = bookingsQuery.docs
          .map((doc) => doc.data()['bookingTime']?.toString() ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
    } catch (e) {
      Log.e('ServiceDetailScreenV2', 'Error fetching bookings: $e');
    }

    if (mounted) {
      setState(() {
        _availableTimeSlots = available;
        _bookedTimeSlots = booked;
        _isLoadingSlots = false;

        // Auto-select first available non-booked slot
        for (var slot in _availableTimeSlots) {
          if (!_bookedTimeSlots.contains(slot)) {
            _selectedTime = slot;
            break;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color orange = Color(0xFFFF7A1A);
    const Color purple = Color(0xFF7D4CFF);
    const Color bg = Color(0xFF08090D);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -50,
            child: IgnorePointer(
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: orange.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: bg.withValues(alpha: 0.8),
                expandedHeight: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'BOOK SERVICE',
                  style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileSummary(orange, purple),
                      const SizedBox(height: 32),
                      _buildTextField(
                        'YOUR NAME',
                        _nameController,
                        Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        'PHONE NUMBER',
                        _phoneController,
                        Icons.phone_android_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        'WHATS THE PROBLEM YOU ARE FACING?',
                        _problemController,
                        Icons.error_outline,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 32),

                      Text(
                        'SELECT DATE',
                        style: GoogleFonts.rajdhani(
                          color: orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDateHeader(orange),
                      const SizedBox(height: 32),
                      Text(
                        'SELECT TIME SLOT',
                        style: GoogleFonts.rajdhani(
                          color: orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTimeSlotsGrid(purple),
                      const SizedBox(height: 32),
                      _buildCouponSection(orange, purple),
                      const SizedBox(height: 32),
                      _buildAppointmentDetails(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomSheet: _buildBottomAction(orange),
    );
  }

  Widget _buildProfileSummary(Color orange, Color purple) {
    final String imgPath = widget.service['img'] ?? '';
    final bool isNetworkImg = imgPath.startsWith('http');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'category_${widget.service['name']}',
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: isNetworkImg
                      ? CachedNetworkImageProvider(imgPath) as ImageProvider
                      : AssetImage(imgPath),
                  fit: BoxFit.cover,
                ),
                border: Border.all(
                  color: orange.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (widget.service['name'] ?? 'SERVICE').toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${widget.service['info'] ?? ''} - ${widget.service['sub'] ?? ''} | ${widget.service['exp'] ?? ''}',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFC107),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.service['rating'] ?? 0} (${widget.service['rev'] ?? 0} Reviews)',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
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
    );
  }

  Widget _buildDateHeader(Color orange) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final bool isAvailable =
              (_partnerSchedule[dateKey] as List?)?.isNotEmpty ?? false;

          return GestureDetector(
            onTap: () => _updateSelectedDateAndSlots(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 65,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? orange.withValues(alpha: 0.15)
                    : const Color(0xFF12121A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? orange
                      : (isAvailable
                            ? orange.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.08)),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getWeekday(date.weekday).toUpperCase(),
                    style: GoogleFonts.rajdhani(
                      color: isSelected
                          ? orange
                          : (isAvailable ? Colors.white70 : Colors.white38),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: GoogleFonts.orbitron(
                      color: isAvailable ? Colors.white : Colors.white24,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (isAvailable && !isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: orange,
                        shape: BoxShape.circle,
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

  String _getWeekday(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  Widget _buildTimeSlotsGrid(Color purple) {
    if (_isLoadingSlots) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Color(0xFFFF7A1A)),
        ),
      );
    }

    if (_availableTimeSlots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF12121A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.event_busy_rounded,
              color: Colors.white24,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'NO BOOKING SLOT AVAILABLE',
              style: GoogleFonts.rajdhani(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: _availableTimeSlots.length,
      itemBuilder: (context, index) {
        final time = _availableTimeSlots[index];
        final isBooked = _bookedTimeSlots.contains(time);
        final isSelected = _selectedTime == time;

        Color slotColor = isBooked
            ? Colors.red.withValues(alpha: 0.2)
            : Colors.green.withValues(alpha: 0.1);
        Color borderColor = isBooked
            ? Colors.red.withValues(alpha: 0.5)
            : Colors.green.withValues(alpha: 0.3);
        Color textColor = isBooked
            ? Colors.red.withValues(alpha: 0.7)
            : Colors.greenAccent;

        if (isSelected) {
          slotColor = purple.withValues(alpha: 0.3);
          borderColor = purple;
          textColor = Colors.white;
        }

        return GestureDetector(
          onTap: isBooked ? null : () => setState(() => _selectedTime = time),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: slotColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            ),
            child: Center(
              child: Text(
                time,
                style: GoogleFonts.rajdhani(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: isSelected || isBooked
                      ? FontWeight.w700
                      : FontWeight.w500,
                  decoration: isBooked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppointmentDetails() {
    final double baseFee = (widget.service['fee'] ?? 0).toDouble();
    final breakdown = PriceCalculator.calculateBookingPrice(baseFee);
    final totalPayable = ((breakdown['totalPayable'] as double) - _couponDiscount)
        .clamp(0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            'Booking Fee',
            '₹${breakdown['basePrice'] + breakdown['markup']}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white10, height: 1),
          ),
          _buildDetailRow('Platform Fee', '₹${breakdown['platformFee']}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white10, height: 1),
          ),
          _buildDetailRow('GST (18%)', '₹${breakdown['gst'].toStringAsFixed(2)}'),
          if (_couponDiscount > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white10, height: 1),
            ),
            _buildDetailRow(
              'Coupon Discount (${_appliedCouponCode ?? ''})',
              '-₹${_couponDiscount.toStringAsFixed(0)}',
              discount: true,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white10, height: 1),
          ),
          _buildDetailRow(
            'Total Payable',
            '₹${totalPayable.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isTotal = false,
    bool discount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.rajdhani(
            color: isTotal ? Colors.white : Colors.white38,
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
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
              ? GoogleFonts.orbitron(
                  color: const Color(0xFF22C55E),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                )
              : GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
        ),
      ],
    );
  }

  Widget _buildCouponSection(Color orange, Color purple) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined, color: orange, size: 18),
              const SizedBox(width: 8),
              Text(
                'COUPONS',
                style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D13),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.white24,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                    ),
                    onSubmitted: (_) => _applyManualCoupon(),
                  ),
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
                    gradient: LinearGradient(
                      colors: [orange, const Color(0xFFFF8A00)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _couponLoading
                        ? []
                        : [
                            BoxShadow(
                              color: orange.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
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
                          style: GoogleFonts.rajdhani(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
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
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF22C55E),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Code $_appliedCouponCode applied',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF22C55E),
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
                    _buildCouponCard(_vendorOffers[index], orange),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCouponCard(CouponModel coupon, Color orange) {
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
              : orange.withValues(alpha: 0.4),
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
              onTap: canApply ? () => _applyCouponFromCard(coupon) : null,
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

  Widget _buildBottomAction(Color orange) {
    final double baseFee = (widget.service['fee'] ?? 0).toDouble();
    final breakdown = PriceCalculator.calculateBookingPrice(baseFee);
    final totalPayable = ((breakdown['totalPayable'] as double) - _couponDiscount)
        .clamp(0, double.infinity);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: const Color(0xFF08090D),
        border: Border(
          top: BorderSide(color: orange.withValues(alpha: 0.15), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL PAYABLE',
                  style: GoogleFonts.rajdhani(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${totalPayable.toStringAsFixed(2)}',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: (_selectedTime.isEmpty || _isProcessing)
                  ? null
                  : _handleBooking,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: _selectedTime.isEmpty
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFFF5F00), Color(0xFFFF8A00)],
                        ),
                  color: _selectedTime.isEmpty ? Colors.white10 : null,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _selectedTime.isEmpty
                      ? []
                      : [
                          BoxShadow(
                            color: orange.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: Center(
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.payment_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'PAY NOW',
                              style: GoogleFonts.rajdhani(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(
            color: const Color(0xFFFF7A1A),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF12121A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white38, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              hintText: 'Enter details here...',
              hintStyle: const TextStyle(color: Colors.white10, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handlePaymentSuccess(PaymentResult result) async {
    Log.p('ServiceDetailScreenV2', 'Payment Success: ${result.paymentId}');

    final user = FirebaseAuth.instance.currentUser;
    final partnerId =
        widget.service['full_partner_data']?['userId'] ??
        widget.service['id'] ??
        '';
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final double baseFee = (widget.service['fee'] ?? 0).toDouble();
    final breakdown = PriceCalculator.calculateBookingPrice(baseFee);
    final totalPayable = ((breakdown['totalPayable'] as double) - _couponDiscount)
        .clamp(0, double.infinity);
    final fullPartner = widget.service['full_partner_data'] ?? {};

    if (user != null && partnerId.isNotEmpty) {
      final bookingData = {
        'userId': user.uid,
        'partnerId': partnerId,
        'customerName': _nameController.text.trim(),
        'customerPhone': _phoneController.text.trim(),
        'problem': _problemController.text.trim(),
        'serviceName': widget.service['name'] ?? 'Service',
        'providerName':
            widget.service['name'] ?? fullPartner['name'] ?? 'Service Provider',
        'providerDetails': {
          'name': fullPartner['name'] ?? widget.service['name'] ?? '',
          'qualification': fullPartner['qualification'] ?? '',
          'specialization':
              fullPartner['specialization'] ??
              (fullPartner['selectedSubCategories'] as List?)?.join(', ') ??
              '',
          'category': fullPartner['category'] ?? widget.category ?? '',
          'experience':
              fullPartner['experience'] ??
              fullPartner['yearsOfExperience'] ??
              '',
          'rating': fullPartner['rating'] ?? '',
          'shopAddress':
              fullPartner['shopAddress'] ?? fullPartner['address'] ?? '',
          'phone': fullPartner['phone'] ?? '',
          'bio': fullPartner['bio'] ?? '',
          'profileImage':
              fullPartner['profileImage'] ?? fullPartner['image'] ?? '',
        },
        'status': 'confirmed',
        'paymentStatus': 'paid',
        'paymentId': result.paymentId,
        'razorpayOrderId': result.orderId,
        'timestamp': FieldValue.serverTimestamp(),
        'bookingDate': dateKey,
        'bookingTime': _selectedTime,
        'date': dateKey,
        'time': _selectedTime,
        'basePrice': breakdown['basePrice'],
        'markup': breakdown['markup'],
        'platformFee': breakdown['platformFee'],
        'gst': breakdown['gst'],
        'couponCode': _appliedCouponCode,
        'couponDiscount': _couponDiscount,
        'totalPrice': totalPayable,
        'profit': breakdown['profit'],
        'price': totalPayable,
      };
      await FirebaseFirestore.instance
          .collection('appointments')
          .add(bookingData);
      if (_appliedOffer?.id != null) {
        await CouponService.recordUsage(_appliedOffer!.id!, user.uid);
      }
    }

    setState(() => _isProcessing = false);
    HapticFeedback.heavyImpact();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentSuccessScreen(
          bookingData: {
            'customerName': _nameController.text.trim(),
            'customerPhone': _phoneController.text.trim(),
            'problem': _problemController.text.trim(),
            'bookingDate': DateFormat('yyyy-MM-dd').format(_selectedDate),
            'bookingTime': _selectedTime,
            'price': breakdown['totalPayable'],
            'basePrice': breakdown['basePrice'],
            'markup': breakdown['markup'],
            'platformFee': breakdown['platformFee'],
            'gst': breakdown['gst'],
            'totalPayable': breakdown['totalPayable'],
            'profit': breakdown['profit'],
            'paymentId': result.paymentId,
            'razorpayOrderId': result.orderId,
          },
          service: {...widget.service, 'category': widget.category},
        ),
      ),
    );
  }

  void _handleBooking() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill Name and Phone Number')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to book an appointment')),
      );
      return;
    }

    if (_selectedTime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final double baseFee = (widget.service['fee'] ?? 0).toDouble();
    final breakdown = PriceCalculator.calculateBookingPrice(baseFee);
    final totalPayable =
        ((breakdown['totalPayable'] as double) - _couponDiscount)
            .clamp(0, double.infinity)
            .toDouble();

    try {
      final PaymentResult? result = await Navigator.push<PaymentResult>(
        context,
        MaterialPageRoute(
          builder: (_) => PremiumPaymentScreen(
            total: totalPayable,
            shopName: 'Multiverse City',
            description: '${widget.service['name'] ?? 'Service'} Booking',
            customerPhone: _phoneController.text.trim(),
            customerEmail: user.email,
            showCod: false,
          ),
        ),
      );

      if (!mounted) return;

      if (result == null || !result.success) {
        setState(() => _isProcessing = false);
        if (result != null && result.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await _handlePaymentSuccess(result);
    } catch (e) {
      Log.e('ServiceDetailScreenV2', 'Error opening payment screen: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open payment gateway')),
        );
      }
    }
  }
}
