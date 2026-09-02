import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/logging_service.dart';
import 'appointment_success_screen.dart';
import '../utils/price_calculator.dart';
import '../services/fee_config_service.dart';

class DoctorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  Map<String, dynamic> _partnerSchedule = {};
  List<String> _availableTimeSlots = [];
  bool _isProcessing = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _problemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _partnerSchedule = widget.doctor["full_partner_data"]?["schedule"] ?? {};
    _updateSelectedDateAndSlots(DateTime.now());
    _feeSub = FeeConfigService.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  StreamSubscription<Map<String, double>>? _feeSub;

  @override
  void dispose() {
    _feeSub?.cancel();
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
  String _selectedTime = '11:00 AM';

  @override
  Widget build(BuildContext context) {
    const Color orange = Color(0xFFFF7A1A);
    const Color purple = Color(0xFF7D4CFF);
    const Color bg = Color(0xFF08090D);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Background glows
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
          Positioned(
            bottom: 100,
            right: -100,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: purple.withValues(alpha: 0.06),
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
                  'BOOK APPOINTMENT',
                  style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.share_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDoctorProfileSummary(orange, purple),
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

  Widget _buildDoctorProfileSummary(Color orange, Color purple) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: orange.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'category_${widget.doctor['name']}',
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: DecorationImage(
                  image: AssetImage(widget.doctor['image']),
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
                  widget.doctor['name'].toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.doctor['qualification'],
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: purple.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    widget.doctor['specialty'].toUpperCase(),
                    style: GoogleFonts.rajdhani(
                      color: purple,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
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
          final isSelected =
              date.day == _selectedDate.day &&
              date.month == _selectedDate.month;

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
                      : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: orange.withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getWeekday(date.weekday).toUpperCase(),
                    style: GoogleFonts.rajdhani(
                      color: isSelected ? orange : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
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
    if (_availableTimeSlots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            "NO BOOKING SLOT AVAILABLE",
            style: GoogleFonts.rajdhani(
              color: Colors.redAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
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
        final isSelected = _selectedTime == time;
        return GestureDetector(
          onTap: () => setState(() => _selectedTime = time),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isSelected
                  ? purple.withValues(alpha: 0.2)
                  : const Color(0xFF12121A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? purple
                    : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                time,
                style: GoogleFonts.rajdhani(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppointmentDetails() {
    final double baseFee = (widget.doctor['fee'] ?? 0).toDouble();
    final breakdown = PriceCalculator.calculateBookingPrice(baseFee);

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
            'Booking Price',
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white10, height: 1),
          ),
          _buildDetailRow(
            'Total Payable',
            '₹${breakdown['totalPayable'].toStringAsFixed(2)}',
            isTotal: true,
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
          label.toUpperCase(),
          style: GoogleFonts.rajdhani(
            color: isTotal ? Colors.white : Colors.white38,
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.orbitron(
            color: isTotal ? const Color(0xFFFF7A1A) : Colors.white,
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction(Color orange) {
    final double baseFee = (widget.doctor['fee'] ?? 0).toDouble();
    final breakdown = PriceCalculator.calculateBookingPrice(baseFee);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: const Color(0xFF08090D),
        border: Border(
          top: BorderSide(color: orange.withValues(alpha: 0.15), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
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
                  '₹${breakdown['totalPayable'].toStringAsFixed(2)}',
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5F00), Color(0xFFFF8A00)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
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
                              Icons.flash_on_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'CONFIRM BOOKING',
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

  void _handleBooking() async {
    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final partnerId =
          widget.doctor['full_partner_data']?['userId'] ??
          widget.doctor['id'] ??
          '';
      final dateKey =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final double baseFee = (widget.doctor['fee'] ?? 0).toDouble();
      final breakdown = PriceCalculator.calculateBookingPrice(baseFee);

      if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill Name and Phone Number')),
        );
        setState(() => _isProcessing = false);
        return;
      }

      if (user != null && partnerId.isNotEmpty) {
        final bookingData = {
          'userId': user.uid,
          'partnerId': partnerId,
          'customerName': _nameController.text.trim(),
          'customerPhone': _phoneController.text.trim(),
          'problem': _problemController.text.trim(),
          'serviceName': widget.doctor['name'] ?? 'Doctor Appointment',
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
          'bookingDate': dateKey,
          'bookingTime': _selectedTime,
          'date': dateKey,
          'time': _selectedTime,
          'basePrice': breakdown['basePrice'],
          'markup': breakdown['markup'],
          'platformFee': breakdown['platformFee'],
          'gst': breakdown['gst'],
          'totalPrice': breakdown['totalPayable'],
          'profit': breakdown['profit'],
          'price': breakdown['totalPayable'], // For backward compatibility if any
        };
        await FirebaseFirestore.instance
            .collection('appointments')
            .add(bookingData);
        // PDF is now generated in Success Screen
        // await _generateBookingPDF(bookingData);
      } else if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to book an appointment')),
        );
        setState(() => _isProcessing = false);
        return;
      }
    } catch (e) {
      Log.e('DoctorDetailScreen', 'Error saving appointment: $e');
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);
    HapticFeedback.heavyImpact();

    final double baseFee = (widget.doctor['fee'] ?? 0).toDouble();
    final breakdown = PriceCalculator.calculateBookingPrice(baseFee);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentSuccessScreen(
          bookingData: {
            'customerName': _nameController.text.trim(),
            'customerPhone': _phoneController.text.trim(),
            'problem': _problemController.text.trim(),
            'bookingDate':
                "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
            'bookingTime': _selectedTime,
            'price': breakdown['totalPayable'],
            'basePrice': breakdown['basePrice'],
            'markup': breakdown['markup'],
            'platformFee': breakdown['platformFee'],
            'gst': breakdown['gst'],
            'totalPayable': breakdown['totalPayable'],
            'profit': breakdown['profit'],
          },
          service: widget.doctor,
        ),
      ),
    );
  }
}

// Test append
