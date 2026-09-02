import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:db_compat/db_compat.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../services/movie_pdf_service.dart';

class MovieTicketScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const MovieTicketScreen({super.key, required this.bookingData});

  @override
  State<MovieTicketScreen> createState() => _MovieTicketScreenState();
}

class _MovieTicketScreenState extends State<MovieTicketScreen> {
  bool _isDownloading = false;
  Map<String, dynamic>? _liveBookingData;
  StreamSubscription? _bookingSubscription;
  int _userRating = 0;
  bool _isRating = false;
  bool _ratingSubmitted = false;

  @override
  void initState() {
    super.initState();
    _liveBookingData = widget.bookingData;
    _startBookingListener();
    _loadExistingRating();
  }

  Future<void> _loadExistingRating() async {
    final movieId = widget.bookingData['movieId']?.toString();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (movieId == null || userId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('movies')
        .doc(movieId)
        .collection('ratings')
        .doc(userId)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _userRating = doc.data()?['rating'] ?? 0;
        _ratingSubmitted = true;
      });
    }
  }

  Future<void> _submitRating(int rating) async {
    if (rating == 0) return;
    setState(() => _isRating = true);

    try {
      final movieId = widget.bookingData['movieId']?.toString();
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (movieId == null || userId == null) return;

      final ratingRef = FirebaseFirestore.instance
          .collection('movies')
          .doc(movieId)
          .collection('ratings')
          .doc(userId);

      await ratingRef.set({
        'rating': rating,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('movies')
          .doc(movieId)
          .collection('ratings')
          .get();

      if (ratingsSnapshot.docs.isEmpty) return;

      double total = 0;
      for (final doc in ratingsSnapshot.docs) {
        total += (doc.data()['rating'] ?? 0).toDouble();
      }
      final average = (total / ratingsSnapshot.docs.length);
      final rounded = double.parse(average.toStringAsFixed(1));

      await FirebaseFirestore.instance.collection('movies').doc(movieId).update(
        {'rating': rounded, 'ratingCount': ratingsSnapshot.docs.length},
      );

      if (mounted) {
        setState(() {
          _userRating = rating;
          _isRating = false;
          _ratingSubmitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startBookingListener() {
    final bookingId = widget.bookingData['bookingId'];
    if (bookingId == null) return;

    _bookingSubscription = FirebaseFirestore.instance
        .collection('movie_bookings')
        .doc(bookingId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            setState(() {
              _liveBookingData = snapshot.data();
            });
          }
        });
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    super.dispose();
  }

  void _downloadTicket() async {
    setState(() => _isDownloading = true);

    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF7A1A)),
        ),
      );

      // Generate the PDF bytes dynamically
      final pdfBytes = await MoviePdfService.generateTicketPdfBytes(
        _liveBookingData ?? widget.bookingData,
      );

      // Save PDF to temp file
      final dir = await getTemporaryDirectory();
      final ticketNo = widget.bookingData['ticketNumber'] ?? 'ticket';
      final pdfFile = File('${dir.path}/Movie_Ticket_$ticketNo.pdf');
      await pdfFile.writeAsBytes(pdfBytes);

      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        setState(() => _isDownloading = false);
      }

      // Share the PDF file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfFile.path)],
          text: 'Movie Ticket - $ticketNo',
        ),
      );
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareTicket() async {
    final ticketNo = _liveBookingData?['ticketNumber'] ?? 'N/A';
    final movie = _liveBookingData?['movieName'] ?? 'Movie';
    final time = _liveBookingData?['showTime'] ?? '';
    final date =
        _liveBookingData?['showDate'] ?? _liveBookingData?['bookingDate'] ?? '';

    final text =
        '🎬 I just booked tickets for $movie!\n🗓 Date: $date\n⏰ Time: $time\n🎫 Ticket No: $ticketNo\n\nSee you at the movies!';
    await Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final d = _liveBookingData ?? widget.bookingData;
    final isCancelled = d['bookingStatus'] == 'cancelled';
    final isUsed = d['isUsed'] == true;

    Color statusColor = const Color(0xFFFF7A1A);
    String statusText = 'CONFIRMED';

    if (isCancelled) {
      statusColor = Colors.redAccent;
      statusText = 'CANCELLED';
    } else if (isUsed) {
      statusColor = Colors.greenAccent;
      statusText = 'USED';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF09090C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: Text(
          'E-TICKET',
          style: GoogleFonts.orbitron(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Status Badge
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                statusText,
                style: GoogleFonts.orbitron(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),

            // Premium Ticket Card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16161E),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.1),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Upper Half: Movie & QR
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Logo
                        Image.asset(
                          'assets/logo.png',
                          height: 40,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                        const SizedBox(height: 20),

                        // Movie Title
                        Text(
                          (d['movieName'] ?? '').toString().toUpperCase(),
                          style: GoogleFonts.orbitron(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${d['theatreName']} - ${d['screenName']}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // QR Code
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: d['qrData'] != null
                                ? (d['qrData'] is String
                                      ? d['qrData']
                                      : jsonEncode(d['qrData']))
                                : jsonEncode({'bookingId': d['bookingId']}),
                            version: QrVersions.auto,
                            size: 160.0,
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
                        const SizedBox(height: 12),
                        Text(
                          d['ticketNumber'] ?? d['bookingId'],
                          style: GoogleFonts.orbitron(
                            fontSize: 12,
                            color: Colors.white54,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ticket Divider (Perforation)
                  Row(
                    children: [
                      Container(
                        width: 15,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Color(0xFF09090C),
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(30),
                          ),
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Flex(
                              direction: Axis.horizontal,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                (constraints.constrainWidth() / 10).floor(),
                                (index) => SizedBox(
                                  width: 5,
                                  height: 2,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        width: 15,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Color(0xFF09090C),
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(30),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Lower Half: Details
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          'DATE',
                          d['date'] ?? d['bookingDate'] ?? '',
                          'TIME',
                          d['time'] ?? d['showTime'] ?? '',
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          'SEATS',
                          (d['seatNumbers'] as List? ??
                                  d['seats'] as List? ??
                                  [])
                              .join(', '),
                          'TICKETS',
                          '${(d['seatNumbers'] as List? ?? d['seats'] as List? ?? []).length}',
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          'CUSTOMER',
                          d['customerName'] ?? '-',
                          'PHONE',
                          d['customerPhone'] ?? '-',
                        ),
                        const Divider(color: Colors.white10, height: 32),

                        // Price Breakdown
                        _buildPriceRow(
                          'Ticket Price',
                          d['ticketPrice'] ??
                              d['totalAmount'] ??
                              d['finalAmount'] ??
                              0,
                        ),
                        _buildPriceRow(
                          'Convenience Fee',
                          d['convenienceFee'] ?? 0,
                        ),
                        _buildPriceRow('Platform Fee', d['platformFee'] ?? 0),
                        _buildPriceRow('GST & Other', d['gst'] ?? 0),
                        const Divider(color: Colors.white10, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL PAID',
                              style: GoogleFonts.orbitron(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '₹${d['totalPaid'] ?? d['finalAmount'] ?? 0}',
                              style: GoogleFonts.orbitron(
                                color: statusColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Payment Method: ${(d['paymentMethod'] ?? '-').toString().toUpperCase()}',
                            style: GoogleFonts.poppins(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : _downloadTicket,
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.download_rounded,
                            color: Colors.black,
                          ),
                    label: Text(
                      'DOWNLOAD',
                      style: GoogleFonts.orbitron(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareTicket,
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                    label: Text(
                      'SHARE',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Rating Section
            if (!isCancelled) _buildRatingSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    final movieName = (_liveBookingData?['movieName'] ?? '').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            _ratingSubmitted ? 'YOUR RATING' : 'RATE THIS MOVIE',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _ratingSubmitted
                ? 'Thanks for rating $movieName!'
                : 'Tap a star to rate',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (_isRating)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.amber,
                strokeWidth: 2,
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIdx = index + 1;
                return GestureDetector(
                  onTap: () => _submitRating(starIdx),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      starIdx <= _userRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: starIdx <= _userRating
                          ? Colors.amber
                          : Colors.white30,
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label1,
    String value1,
    String label2,
    String value2,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label1,
                style: GoogleFonts.poppins(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value1,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label2,
                style: GoogleFonts.poppins(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value2,
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

  Widget _buildPriceRow(String label, dynamic amount) {
    final displayAmount = amount ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
          ),
          Text(
            '₹$displayAmount',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
