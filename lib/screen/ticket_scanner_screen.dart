import 'package:db_compat/db_compat.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/premium_ui_widgets.dart';

class TicketScannerScreen extends StatefulWidget {
  const TicketScannerScreen({super.key});

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen> {
  final TextEditingController _bookingIdController = TextEditingController();
  bool _isVerifying = false;
  Map<String, dynamic>? _verificationResult;
  String? _errorMessage;

  @override
  void dispose() {
    _bookingIdController.dispose();
    super.dispose();
  }

  Future<void> _verifyTicket() async {
    if (_bookingIdController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a booking ID';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _verificationResult = null;
    });

    try {
      final bookingId = _bookingIdController.text.trim();

      // Fetch booking from Firebase
      final doc = await FirebaseFirestore.instance
          .collection('movie_bookings')
          .doc(bookingId)
          .get();

      if (!doc.exists) {
        setState(() {
          _errorMessage = 'Invalid booking ID';
          _isVerifying = false;
        });
        return;
      }

      final bookingData = doc.data()!;

      // Check if ticket is expired
      final expiresAt = (bookingData['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        setState(() {
          _verificationResult = {
            'valid': false,
            'reason': 'Ticket expired',
            'data': bookingData,
          };
          _isVerifying = false;
        });
        return;
      }

      // Check if already used
      if (bookingData['status'] == 'used') {
        setState(() {
          _verificationResult = {
            'valid': false,
            'reason': 'Ticket already used',
            'data': bookingData,
          };
          _isVerifying = false;
        });
        return;
      }

      // Valid ticket
      setState(() {
        _verificationResult = {'valid': true, 'data': bookingData};
        _isVerifying = false;
      });

      // Mark as used
      await FirebaseFirestore.instance
          .collection('movie_bookings')
          .doc(bookingId)
          .update({'status': 'used', 'usedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed: $e';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0D), Color(0xFF1A0B2E), Color(0xFF09090C)],
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
                    children: [
                      _buildInputSection(),
                      const SizedBox(height: 30),
                      if (_isVerifying) _buildLoadingIndicator(),
                      if (_errorMessage != null) _buildErrorCard(),
                      if (_verificationResult != null)
                        _buildVerificationResult(),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              'VERIFY TICKET',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const Icon(
            Icons.verified_user_rounded,
            color: Color(0xFF4ADE80),
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return GlassCard(
      margin: EdgeInsets.zero,
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENTER BOOKING ID',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bookingIdController,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g., MB_1234567890_abc12345',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFFF7A1A),
                  width: 2,
                ),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54),
                onPressed: () => _bookingIdController.clear(),
              ),
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A1A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'VERIFY TICKET',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFFF7A1A),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Verifying ticket...',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF87171).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF87171).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationResult() {
    final isValid = _verificationResult!['valid'] as bool;
    final bookingData = _verificationResult!['data'] as Map<String, dynamic>;

    return GlassCard(
      margin: EdgeInsets.zero,
      borderRadius: 28,
      child: Column(
        children: [
          // Status Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isValid
                  ? const Color(0xFF4ADE80).withValues(alpha: 0.1)
                  : const Color(0xFFF87171).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isValid
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFF87171),
                  size: 80,
                ),
                const SizedBox(height: 16),
                Text(
                  isValid ? 'VALID TICKET' : 'INVALID TICKET',
                  style: GoogleFonts.orbitron(
                    color: isValid
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!isValid && _verificationResult!['reason'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _verificationResult!['reason'],
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Booking Details
          if (isValid)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('MOVIE', bookingData['movieName']),
                  const SizedBox(height: 12),
                  _buildDetailRow('THEATRE', bookingData['theatreName']),
                  const SizedBox(height: 12),
                  _buildDetailRow('DATE', bookingData['bookingDate']),
                  const SizedBox(height: 12),
                  _buildDetailRow('TIME', bookingData['showTime']),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'SEATS',
                    (bookingData['selectedSeats'] as List).join(', '),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('BOOKING ID', bookingData['bookingId']),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'AMOUNT',
                    '₹${(bookingData['totalAmount'] as num).toStringAsFixed(0)}',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.orbitron(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
