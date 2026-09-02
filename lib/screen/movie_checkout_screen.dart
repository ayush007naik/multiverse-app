import 'dart:convert';
import 'dart:async';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/premium_ui_widgets.dart';
import 'package:rxdart/rxdart.dart';
import '../models/payment_method.dart';
import '../models/coupon_model.dart';
import '../services/coupon_service.dart';
import '../services/fee_config_service.dart';
import '../services/theatre_service.dart';
import '../services/movie_pdf_service.dart';
import '../core/logging_service.dart';
import 'my_tickets_screen.dart';
import 'premium_payment_screen.dart';

class MovieCheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> movieData;
  final List<String> selectedSeats;
  final Map<String, dynamic> selectedCinema;
  final String selectedShowId;
  final String selectedTime;
  final DateTime selectedDate;
  final double totalAmount;
  final double ownerTicketAmount;
  final Map<String, dynamic> seatPricing;

  const MovieCheckoutScreen({
    super.key,
    required this.movieData,
    required this.selectedSeats,
    required this.selectedCinema,
    required this.selectedShowId,
    required this.selectedTime,
    required this.selectedDate,
    required this.totalAmount,
    required this.ownerTicketAmount,
    required this.seatPricing,
  });

  @override
  State<MovieCheckoutScreen> createState() => _MovieCheckoutScreenState();
}

class _MovieCheckoutScreenState extends State<MovieCheckoutScreen>
    with TickerProviderStateMixin {
  bool _isProcessing = false;

  // Customer Info
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // Real-time Coupons
  List<Map<String, dynamic>> _availableOffers = [];
  bool _isLoadingOffers = true;
  StreamSubscription? _couponSubscription;
  StreamSubscription<Map<String, double>>? _feeSub;
  String? _appliedCoupon;
  double _couponDiscount = 0;
  final TextEditingController _couponController = TextEditingController();

  // Fees
  double get _convenienceFee => FeeConfigService.movieConvenienceFee;
  double get _platformFee => FeeConfigService.moviePlatformFee;
  double get _gstRate => FeeConfigService.gstRate;

  // Animation controllers
  late AnimationController _successController;
  bool _showSuccessAnimation = false;

  @override
  void initState() {
    super.initState();
    _prefillCustomerInfo();
    _fetchRealTimeCoupons();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _feeSub = FeeConfigService.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _prefillCustomerInfo() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _phoneController.text = _normalizePhone(user.phoneNumber ?? '');
    }
  }

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10 && digits.startsWith('91')) {
      return digits.substring(digits.length - 10);
    }
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  void _fetchRealTimeCoupons() {
    final theatreId = widget.selectedCinema['id'];
    if (theatreId == null) {
      setState(() => _isLoadingOffers = false);
      return;
    }

    // Combine theatre-specific coupons and global admin coupons
    final theatreStream = TheatreService.getTheatreCoupons(theatreId);
    final globalStream = CouponService.streamActiveByVendor('ADMIN');

    final combinedStream = CombineLatestStream.list([
      theatreStream,
      globalStream,
    ]);

    final subscription = combinedStream.listen(
      (snapshots) {
        if (mounted) {
          final Set<String> uniqueCodes = {};
          final List<Map<String, dynamic>> allCoupons = [];

          for (var snapshot in snapshots) {
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final appliesTo = data['appliesTo']?.toString() ?? '';
              if (appliesTo.isNotEmpty &&
                  appliesTo != CouponModel.scopeAll &&
                  appliesTo != CouponModel.scopeMovies) {
                continue;
              }
              data['id'] = doc.id;
              final code = (data['code'] ?? data['couponCode'])
                      ?.toString()
                      .toUpperCase() ??
                  '';
              if (code.isNotEmpty && !uniqueCodes.contains(code)) {
                uniqueCodes.add(code);
                data['code'] = code;
                allCoupons.add(data);
              }
            }
          }

          setState(() {
            _availableOffers = allCoupons;
            _isLoadingOffers = false;
          });
        }
      },
      onError: (e) {
        if (mounted) setState(() => _isLoadingOffers = false);
      },
    );

    _couponSubscription = subscription;
  }

  @override
  void dispose() {
    _feeSub?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _couponSubscription?.cancel();
    _couponController.dispose();
    _successController.dispose();
    super.dispose();
  }

  double get _bookingFee => FeeConfigService.movieBookingFee;
  double get _gstAndOtherCharges =>
      ((_bookingFee * _gstRate) + 5).roundToDouble();
  double get _subtotal =>
      widget.totalAmount + _bookingFee + _gstAndOtherCharges;
  double get _finalAmount => _subtotal - _couponDiscount;

  void _applyCoupon() async {
    String code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final result = await CouponService.applyCoupon(
        code: code,
        vendorId: widget.selectedCinema['id'] ?? '',
        orderAmount: widget.totalAmount,
        userId: user?.uid,
        appliesTo: CouponModel.scopeMovies,
      );

      if (mounted) {
        if (result.success) {
          setState(() {
            _appliedCoupon = result.coupon!.code;
            _couponDiscount = result.discount;
          });
          _showSnackbar('Coupon Applied: $_appliedCoupon', isSuccess: true);
        } else {
          setState(() {
            _appliedCoupon = null;
            _couponDiscount = 0;
          });
          _showSnackbar(result.error ?? 'Invalid Coupon Code');
        }
      }
    } catch (e) {
      if (mounted) _showSnackbar('Error applying coupon');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0;
      _couponController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccessAnimation) {
      return _buildSuccessAnimation();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CHECKOUT',
          style: GoogleFonts.orbitron(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      _buildMovieCard(),
                      const SizedBox(height: 25),
                      _buildSelectedSeatsSection(),
                      const SizedBox(height: 25),
                      _buildCouponSection(),
                      const SizedBox(height: 25),
                      _buildOffersSection(),
                      const SizedBox(height: 25),
                      _buildPriceBreakdown(),
                      const SizedBox(height: 25),
                      _buildCustomerInfoSection(),
                    ],
                  ),
                ),
              ),
            ),
            _buildStickyPayButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieCard() {
    return NeonContainer(
      glowColor: const Color(0xFF7D4CFF),
      containerColor: Colors.white.withValues(alpha: 0.03),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 90,
              height: 130,
              child:
                  widget.movieData['poster'] != null &&
                      widget.movieData['poster'].toString().startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: widget.movieData['poster'],
                      fit: BoxFit.cover,
                    )
                  : Image.asset(
                      widget.movieData['poster'] ??
                          'assets/banners/banner4.png',
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.movieData['title']?.toUpperCase() ?? 'MOVIE NAME',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.movieData['language'] ?? 'Hindi'} • ${widget.movieData['duration'] ?? '2h 45m'}',
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.selectedCinema['cinemaName'] ?? 'Theatre Name',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFF7A1A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Screen 1', // Placeholder or add to widget props
                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white38,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${widget.selectedDate.day} ${_getMonthName(widget.selectedDate.month)} ${widget.selectedDate.year}',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.access_time_rounded,
                      color: Colors.white38,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.selectedTime,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
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

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Widget _buildSelectedSeatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('SELECTED SEATS'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: widget.selectedSeats.map((seat) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A1A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFF7A1A).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                seat,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Text(
          'Total: ${widget.selectedSeats.length} Tickets',
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPriceBreakdown() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('PRICE BREAKDOWN'),
          const SizedBox(height: 15),
          _buildPriceRow(
            'Ticket Price',
            '₹${widget.totalAmount.toStringAsFixed(0)}',
          ),
          _buildPriceRow(
            'Booking Fee',
            '₹${_bookingFee.toStringAsFixed(0)}',
          ),
          _buildPriceRow(
            'GST & Other Charges',
            '₹${_gstAndOtherCharges.toStringAsFixed(0)}',
          ),
          if (_couponDiscount > 0) ...[
            _buildPriceRow(
              'Coupon Discount',
              '-₹${_couponDiscount.toStringAsFixed(0)}',
              valueColor: Colors.green,
            ),
          ],
          const Divider(color: Colors.white10, height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Final Amount',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '₹${_finalAmount.toStringAsFixed(0)}',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFFFF7A1A),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: valueColor ?? Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoSection() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('CUSTOMER INFO'),
          const SizedBox(height: 15),
          TextFormField(
            controller: _nameController,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Full Name *',
              labelStyle: GoogleFonts.poppins(color: Colors.white60),
              prefixIcon: const Icon(
                Icons.person_outline,
                color: Colors.white60,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFFF7A1A)),
                borderRadius: BorderRadius.circular(12),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red),
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Phone Number *',
              labelStyle: GoogleFonts.poppins(color: Colors.white60),
              prefixIcon: const Icon(
                Icons.phone_outlined,
                color: Colors.white60,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFFF7A1A)),
                borderRadius: BorderRadius.circular(12),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red),
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your phone number';
              }
              if (value.trim().length != 10) {
                return 'Phone number must be 10 digits';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCouponSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('APPLY COUPON'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _couponController,
                textCapitalization: TextCapitalization.characters,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter Coupon Code',
                  hintStyle: GoogleFonts.poppins(color: Colors.white24),
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF7A1A)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _applyCoupon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A1A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: Text(
                  'APPLY',
                  style: GoogleFonts.orbitron(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_appliedCoupon != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coupon Applied: $_appliedCoupon',
                        style: GoogleFonts.poppins(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'You saved ₹${_couponDiscount.toStringAsFixed(0)}!',
                        style: GoogleFonts.poppins(
                          color: Colors.green.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _removeCoupon,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOffersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('AVAILABLE OFFERS'),
        const SizedBox(height: 12),
        if (_isLoadingOffers)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF7A1A)),
          )
        else if (_availableOffers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'No offers available for this cinema',
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableOffers.length,
              itemBuilder: (context, index) {
                return _buildOfferCard(
                  _offerToModel(_availableOffers[index]),
                );
              },
            ),
          ),
      ],
    );
  }

  CouponModel _offerToModel(Map<String, dynamic> offer) {
    final data = Map<String, dynamic>.from(offer);
    if (data['discountPercentage'] == null &&
        data['discountPercent'] != null) {
      data['discountPercentage'] = data['discountPercent'];
    }
    final title =
        data['title']?.toString() ??
        data['couponName']?.toString() ??
        data['couponCode']?.toString() ??
        data['code']?.toString() ??
        'Coupon';
    data['title'] = title;
    return CouponModel.fromMap(data, (data['id'] ?? '').toString());
  }

  Widget _buildOfferCard(CouponModel coupon) {
    final title = coupon.title;
    final couponCode = coupon.code;
    final description = coupon.description;
    final isApplied = _appliedCoupon == couponCode;
    final subtotalLocal = widget.totalAmount;
    final canApply = subtotalLocal >= coupon.minOrderValue;
    final deficit = coupon.minOrderValue - subtotalLocal;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isApplied
            ? const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
              )
            : const LinearGradient(
                colors: [Color(0xFF1A1A24), Color(0xFF14141C)],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isApplied
              ? const Color(0xFF4CAF50)
              : Colors.white.withValues(alpha: 0.3),
          width: isApplied ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isApplied
                ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.confirmation_num, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
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
              color: isApplied
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              coupon.discountLabel,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.confirmation_num_outlined,
                  color: isApplied
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'Code: $couponCode',
                  style: GoogleFonts.poppins(
                    color: isApplied
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          if (description.isNotEmpty)
            Text(
              description,
              style: GoogleFonts.poppins(
                color: isApplied
                    ? Colors.white.withValues(alpha: 0.8)
                    : const Color(0xFFA1A1AA),
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (coupon.minOrderValue > 0)
            Text(
              coupon.subtitle,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 8),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          if (!isApplied)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canApply
                    ? () {
                        _couponController.text = couponCode;
                        _applyCoupon();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canApply
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.1),
                  foregroundColor: canApply ? Colors.black : Colors.white38,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  canApply ? 'APPLY' : 'ADD ₹${deficit.toInt()} MORE',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: canApply ? 11 : 9,
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _removeCoupon,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '✓ APPLIED',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.cancel,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStickyPayButton() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: NeonButton(
            text: _isProcessing ? 'PROCESSING...' : 'PROCEED TO PAY',
            onPressed: _isProcessing ? null : _startPayment,
            glowColor: const Color(0xFFFF7A1A),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.orbitron(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }

  void _startPayment() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackbar('Please complete customer information');
      return;
    }
    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Login required');

      // Lock seats
      await TheatreService.lockSeats(
        showId: widget.selectedShowId,
        seats: widget.selectedSeats,
        userId: user.uid,
      );

      if (!mounted) return;

      Log.p('MovieCheckoutScreen', 'Opening payment screen...');

      final PaymentResult? result = await Navigator.push<PaymentResult>(
        context,
        MaterialPageRoute(
          builder: (_) => PremiumPaymentScreen(
            total: _finalAmount,
            shopName:
                widget.selectedCinema['cinemaName']?.toString() ??
                    'Multiverse Cinema',
            description: "Movie Ticket: ${widget.movieData['title']}",
            customerPhone: _phoneController.text.trim(),
            customerEmail: user.email,
            showCod: false,
          ),
        ),
      );

      if (!mounted) return;

      if (result == null) {
        // User backed out without paying
        setState(() => _isProcessing = false);
        unawaited(_releaseSeatLock());
        return;
      }

      if (!result.success) {
        setState(() => _isProcessing = false);
        unawaited(_releaseSeatLock());
        _openPaymentFailedScreen(
          result.message ?? 'Payment failed. Please try again.',
        );
        return;
      }

      await _finalizeBooking(
        paymentStatus: 'paid',
        paymentMethod: 'RAZORPAY',
        paymentId: result.paymentId ?? '',
        isTestBooking: false,
      );
    } catch (e) {
      Log.e('MovieCheckoutScreen', 'Error: $e');
      if (mounted) setState(() => _isProcessing = false);
      unawaited(_releaseSeatLock());
      _showSnackbar('Payment initialization failed: ${e.toString()}');
    }
  }

  Future<void> _finalizeBooking({
    required String paymentStatus,
    required String paymentMethod,
    required String paymentId,
    required bool isTestBooking,
  }) async {
    setState(() {
      _isProcessing = false;
      _showSuccessAnimation = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final dateNow = DateTime.now();
      final dateString =
          "${dateNow.year}${dateNow.month.toString().padLeft(2, '0')}${dateNow.day.toString().padLeft(2, '0')}";
      final randomId = dateNow.millisecondsSinceEpoch.toString().substring(
        9,
      ); // 4 digit random
      final ticketNumber = 'MVC-TKT-$dateString-$randomId';
      final bookingId = 'MB_${dateNow.millisecondsSinceEpoch}';

      // Format date for MyTicketsScreen (ISO format YYYY-MM-DD)
      final isoDate =
          "${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}";

      // Create QR Payload structure exactly as requested
      final qrPayload = {
        "ticketId": ticketNumber,
        "bookingId": bookingId,
        "customerName": _nameController.text.trim(),
        "movieName": widget.movieData['title'],
        "theatreId": widget.selectedCinema['id'],
        "seatNumbers": widget.selectedSeats,
      };

      final bookingData = {
        'ticketNumber': ticketNumber,
        'bookingId': bookingId,
        'userId': user.uid,
        'customerName': _nameController.text.trim(),
        'customerPhone': _phoneController.text.trim(),
        'movieId': widget.movieData['id']?.toString() ?? '',
        'movieName': widget.movieData['title'],
        'movieData': widget.movieData,
        'theatreId': widget.selectedCinema['id'],
        'theatreName': widget.selectedCinema['cinemaName'],
        'screenName': 'Screen 1', // TODO: Get from shows data
        'showId': widget.selectedShowId,
        'selectedSeats': widget.selectedSeats,
        'seats': widget.selectedSeats,
        'seatNumbers': widget.selectedSeats,
        'ticketPrice': widget.ownerTicketAmount,
        'customerTicketPrice': widget.totalAmount,
        'platformTicketFee': widget.totalAmount - widget.ownerTicketAmount,
        'convenienceFee': _convenienceFee,
        'platformFee': _platformFee,
        'bookingFee': _bookingFee,
        'gst': _gstAndOtherCharges,
        'couponCode': _appliedCoupon,
        'couponDiscount': _couponDiscount,
        'finalAmount': _finalAmount,
        'totalAmount': _finalAmount,
        'totalPaid': _finalAmount,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'bookingStatus': 'confirmed',
        'paymentId': paymentId,
        'isTestBooking': isTestBooking,
        'createdAt': FieldValue.serverTimestamp(),
        'showTime': widget.selectedTime,
        'time': widget.selectedTime,
        'showDate': isoDate,
        'date': isoDate,
        'bookingDate': isoDate,
        'qrData': qrPayload,
        'isUsed': false,
      };

      // Create the booking directly to avoid "Permission Denied" on shows collection
      await TheatreService.createBooking(bookingData);

      // Record coupon usage if applicable
      if (_appliedCoupon != null) {
        final matchingCoupon = _availableOffers.firstWhere(
          (c) => c['code'].toString().toUpperCase() == _appliedCoupon,
          orElse: () => {},
        );
        if (matchingCoupon['id'] != null) {
          await CouponService.recordUsage(matchingCoupon['id'], user.uid);
        }
      }

      // Start PDF generation in background
      MoviePdfService.generateAndUploadTicket(bookingData);

      // Trigger 5 second animation then move to ticket
      await Future.delayed(const Duration(seconds: 5));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QRTicketScreen(bookingData: bookingData),
          ),
        );
      }
    } catch (e) {
      _showSnackbar('Booking failed: ${e.toString()}');
      setState(() {
        _showSuccessAnimation = false;
        _isProcessing = false;
      });
    }
  }

  Future<void> _releaseSeatLock() async {
    try {
      await TheatreService.unlockSeats(showId: widget.selectedShowId);
    } catch (e) {
      Log.i('MovieCheckoutScreen', 'Could not release movie seat lock: $e');
    }
  }

  void _openPaymentFailedScreen(String message) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MoviePaymentFailedScreen(
          message: message,
          onRetry: () {
            Navigator.of(context).pop();
            _startPayment();
          },
        ),
      ),
    );
  }

  void _showSnackbar(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PulsingAnimation(
              duration: const Duration(seconds: 1),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.green, Color(0xFF00FF88)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 90,
                ),
              ),
            ),
            const SizedBox(height: 50),
            FadeSlideAnimation(
              duration: const Duration(seconds: 1),
              child: Text(
                'BOOKING SUCCESSFUL!',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 15),
            FadeSlideAnimation(
              duration: const Duration(seconds: 1),
              delay: const Duration(milliseconds: 500),
              child: Text(
                'TICKETS CONFIRMED',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFFFF7A1A),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 30),
            FadeSlideAnimation(
              duration: const Duration(seconds: 1),
              delay: const Duration(milliseconds: 1000),
              child: Text(
                'Generating your premium ticket...',
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
              ),
            ),
            const SizedBox(height: 50),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: Color(0xFFFF7A1A),
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MoviePaymentFailedScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const MoviePaymentFailedScreen({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.18),
                      blurRadius: 36,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.redAccent,
                  size: 72,
                ),
              ),
              const SizedBox(height: 34),
              Text(
                'PAYMENT FAILED',
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 34),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A1A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'RETRY PAYMENT',
                    style: GoogleFonts.orbitron(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'BACK TO CHECKOUT',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QRTicketScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;

  const QRTicketScreen({super.key, required this.bookingData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'CINEMA TICKET',
          style: GoogleFonts.orbitron(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            BreathingNeonContainer(
              glowColor: const Color(0xFFFF7A1A),
              borderRadius: 30,
              padding: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  children: [
                    // Ticket Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF7A1A,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.movie_filter_rounded,
                              color: Color(0xFFFF7A1A),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bookingData['movieName']
                                          ?.toString()
                                          .toUpperCase() ??
                                      '',
                                  style: GoogleFonts.orbitron(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  bookingData['theatreName'] ?? '',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main QR Code Section
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 35),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: jsonEncode({
                                'bid': bookingData['bookingId'],
                                'uid': bookingData['userId'],
                                'seats': bookingData['selectedSeats'],
                              }),
                              version: QrVersions.auto,
                              size: 180.0,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'BOOKING ID: ${bookingData['bookingId']}',
                            style: GoogleFonts.orbitron(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Ticket Details
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _buildDetailRow('DATE', bookingData['date'] ?? ''),
                          const SizedBox(height: 18),
                          _buildDetailRow('TIME', bookingData['time'] ?? ''),
                          const SizedBox(height: 18),
                          _buildDetailRow(
                            'SEATS',
                            (bookingData['selectedSeats'] as List).join(', '),
                          ),
                          const SizedBox(height: 18),
                          _buildDetailRow(
                            'TOTAL PAID',
                            '₹${bookingData['finalAmount']}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 35),

                    // Dashed Divider with Cutouts
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          children: List.generate(
                            30,
                            (index) => Expanded(
                              child: Container(
                                height: 1,
                                color: index % 2 == 0
                                    ? Colors.white12
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -15,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -15,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 25),
                      child: Text(
                        'SCAN AT ENTRANCE',
                        style: GoogleFonts.orbitron(
                          color: const Color(0xFF7D4CFF),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: NeonButton(
                    text: 'SHARE',
                    onPressed: () {
                      Share.share(
                        'Hey! I just booked tickets for ${bookingData['movieName']} at ${bookingData['theatreName']}. Booking ID: ${bookingData['bookingId']}',
                      );
                    },
                    isSecondary: true,
                    glowColor: const Color(0xFF7D4CFF),
                    height: 50,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeonButton(
                    text: 'DOWNLOAD',
                    onPressed: () {
                      // Logic for download
                    },
                    glowColor: const Color(0xFFFF7A1A),
                    height: 50,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            NeonButton(
              text: 'VIEW BOOKING',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
                );
              },
              isSecondary: true,
              glowColor: Colors.white54,
              height: 50,
            ),
            const SizedBox(height: 30),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text(
                'BACK TO HOME',
                style: GoogleFonts.orbitron(
                  color: Colors.white24,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.orbitron(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
