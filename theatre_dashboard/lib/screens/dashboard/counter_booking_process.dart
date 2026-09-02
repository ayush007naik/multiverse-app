import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qr/qr.dart';
import 'package:image/image.dart' as img;
import '../../theme/cyberpunk_theme.dart';
import '../../services/theatre_service.dart';
import '../../utils/ticket_pdf_generator.dart';

class CounterBookingProcess extends StatefulWidget {
  final String showId;
  final Map<String, dynamic> showData;
  final VoidCallback onBack;

  const CounterBookingProcess({
    super.key,
    required this.showId,
    required this.showData,
    required this.onBack,
  });

  @override
  State<CounterBookingProcess> createState() => _CounterBookingProcessState();
}

class _CounterBookingProcessState extends State<CounterBookingProcess> {
  final List<String> _selectedSeats = [];
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _paymentMode = 'Cash';
  bool _isBooking = false;
  String? _lastBookingId;

  double get _totalAmount {
    final pricing = Map<String, dynamic>.from(widget.showData['pricing'] ?? {});
    final seatLayout = widget.showData['seatLayout'] as Map<String, dynamic>?;
    final rowCategories = List<String>.from(seatLayout?['rowCategories'] ?? []);
    final rowLabels = List<String>.from(seatLayout?['rowLabels'] ?? []);

    double total = 0;
    for (var seatId in _selectedSeats) {
      final rowLabel = seatId.replaceAll(RegExp(r'[0-9]'), '');
      final rowIndex = rowLabels.indexOf(rowLabel);
      if (rowIndex != -1 && rowIndex < rowCategories.length) {
        final category = rowCategories[rowIndex];
        total += (pricing[category] ?? 0).toDouble();
      }
    }
    return total;
  }

  String? get _posterUrl {
    final raw = widget.showData['moviePoster'] ?? widget.showData['moviePosterUrl'];
    if (raw == null) return null;
    final url = raw.toString().trim();
    if (url.isEmpty || url.startsWith('https://via.placeholder.com')) return null;
    return url;
  }

  DateTime get _showStartTime {
    final raw = widget.showData['startTime'];
    if (raw is Timestamp) return raw.toDate();
    return DateTime.now();
  }

  Future<void> _confirmBooking() async {
    if (_selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one seat')),
      );
      return;
    }
      setState(() => _isBooking = true);

    try {
      final email = _emailController.text.trim();
      // Normalize phone to store last 10 digits for consistent matching
      final rawPhone = _phoneController.text.trim();
      final phoneDigits = rawPhone.replaceAll(RegExp(r'\D'), '');
      final phone = phoneDigits.length > 10
          ? phoneDigits.substring(phoneDigits.length - 10)
          : phoneDigits;

      // 1. Customer Lookup via Cloud Function
      bool isRegistered = false;
      Map<String, dynamic> lookupData = {};
      
      try {
        if (phone.isNotEmpty) {
          final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
          final result = await functions.httpsCallable('checkCustomerByPhone').call({'phone': phone});
          lookupData = Map<String, dynamic>.from(result.data as Map);
          isRegistered = lookupData['registered'] == true;
        }
      } catch (e) {
        debugPrint('Customer lookup failed: $e');
        // Continue as guest if lookup fails, but warn if it's a protocol error
        if (e.toString().contains('invalid-argument')) {
             debugPrint('Invalid argument passed to lookup: $phone');
        }
      }

      if (!isRegistered && email.isEmpty) {
        setState(() => _isBooking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer not found. Email is required for guest bookings.'), backgroundColor: Colors.orange),
        );
        return;
      }

      // 2. Create Initial Booking Record
      final theatreService = Provider.of<TheatreService>(context, listen: false);
      final customerUid = isRegistered ? lookupData['userId']?.toString() : null;
      String bookingId;
      try {
        bookingId = await theatreService.createOfflineBooking(
          showId: widget.showId,
          movieId: widget.showData['movieId'],
          movieTitle: widget.showData['movieTitle'],
          moviePoster: _posterUrl ?? '',
          showTime: DateFormat('dd MMM yyyy • hh:mm a').format(_showStartTime),
          screen: widget.showData['screen'],
          seats: _selectedSeats,
          totalAmount: _totalAmount,
          paymentMode: _paymentMode,
          customerName: _nameController.text.trim(),
          customerPhone: phone,
          customerEmail: email,
          customerUid: customerUid,
          sendSMS: false, // We trigger notification manually after PDF upload
          sendWhatsApp: false,
          sendEmail: false,
        );
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          throw 'Permission Denied: Staff cannot create booking. Check Firestore Rules.';
        }
        throw 'Firestore Error: $e';
      }

      // 3. Generate and Upload PDF
      String? pdfUrl;
      try {
        final theatreSnap = await FirebaseFirestore.instance.collection('theatres').doc(theatreService.currentUid).get();
        final theatreData = theatreSnap.data();
        final theatreName = theatreData?['name'] ?? theatreData?['cinemaName'] ?? 'Multiverse Cinema';
        final bookingData = <String, dynamic>{
          'bookingId': bookingId,
          'movieTitle': widget.showData['movieTitle'],
          'theatreName': theatreName,
          'screen': widget.showData['screen'],
          'showTime': DateFormat('dd MMM yyyy • hh:mm a').format(_showStartTime),
          'seats': _selectedSeats,
          'totalAmount': _totalAmount,
          'paymentMethod': _paymentMode,
          'customerName': _nameController.text.trim(),
          'customerPhone': phone,
          'customerEmail': email,
        };

        final pdfBytes = await TicketPdfGenerator.generateTicket(
          booking: bookingData,
          moviePosterUrl: _posterUrl,
        );

        final storageRef = FirebaseStorage.instance.ref().child('tickets/$bookingId.pdf');
        await storageRef.putData(pdfBytes, const SettableMetadata(contentType: 'application/pdf'));
        pdfUrl = await storageRef.getDownloadURL();
      } catch (e) {
        debugPrint('PDF Storage Error: $e');
        // Don't crash if PDF fails, booking is already saved.
      }

      // 4. Generate and Upload QR Image (used by email cloud function as CID)
      String? qrImageUrl;
      try {
        final qrCode = QrCode.fromData(
          data: bookingId,
          errorCorrectLevel: QrErrorCorrectLevel.H,
        );
        final qrImage = QrImage(qrCode);
        final moduleCount = qrImage.moduleCount;
        const qrSize = 500;
        final pixels = Uint8List(qrSize * qrSize * 4);
        final pixelSize = qrSize / moduleCount;
        for (int y = 0; y < qrSize; y++) {
          for (int x = 0; x < qrSize; x++) {
            final modY = (y / pixelSize).floor().clamp(0, moduleCount - 1);
            final modX = (x / pixelSize).floor().clamp(0, moduleCount - 1);
            final dark = qrImage.isDark(modY, modX);
            final offset = (y * qrSize + x) * 4;
            pixels[offset] = dark ? 0 : 255;
            pixels[offset + 1] = dark ? 0 : 255;
            pixels[offset + 2] = dark ? 0 : 255;
            pixels[offset + 3] = 255;
          }
        }
        final image = img.Image.fromBytes(
          width: qrSize,
          height: qrSize,
          bytes: pixels.buffer,
          numChannels: 4,
        );
        final qrPngBytes = Uint8List.fromList(img.encodePng(image));
        final qrRef = FirebaseStorage.instance.ref().child('tickets/qr_$bookingId.png');
        await qrRef.putData(qrPngBytes, const SettableMetadata(contentType: 'image/png'));
        qrImageUrl = await qrRef.getDownloadURL();
      } catch (e) {
        debugPrint('QR Image Generation Error: $e');
      }

      // 5. Finalize Booking Status
      try {
        final startTime = widget.showData['startTime'] as Timestamp?;
        final isoDate = startTime != null
            ? DateFormat('yyyy-MM-dd').format(startTime.toDate())
            : DateTime.now().toIso8601String().substring(0, 10);
        final timeOnly = startTime != null
            ? DateFormat('hh:mm a').format(startTime.toDate())
            : '';

        final updateData = <String, dynamic>{
          'processingStatus': 'pending_notification',
          'pdfGeneratedAt': FieldValue.serverTimestamp(),
          'date': isoDate,
          'showDate': isoDate,
          'bookingDate': isoDate,
          'time': timeOnly,
          'movieName': widget.showData['movieTitle'],
        };
        
        if (pdfUrl != null) updateData['pdfUrl'] = pdfUrl;
        if (qrImageUrl != null) updateData['qrImageUrl'] = qrImageUrl;

        await FirebaseFirestore.instance.collection('movie_bookings').doc(bookingId).update(updateData);
      } catch (e) {
        debugPrint('Final update failed: $e');
        if (e.toString().contains('permission-denied')) {
          throw 'Permission Denied: Staff cannot update booking status.';
        }
      }

      setState(() {
        _lastBookingId = bookingId;
        _isBooking = false;
      });

      _showSuccessDialog(isRegistered: isRegistered);
    } catch (e) {
      setState(() => _isBooking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessDialog({bool isRegistered = false}) async {
    final bookingSnap = await FirebaseFirestore.instance.collection('movie_bookings').doc(_lastBookingId).get();
    final bookingData = bookingSnap.data()!;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: CyberpunkTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 12),
            Text('BOOKING SUCCESSFUL'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_posterUrl != null)
              Container(
                height: 120,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black26,
                ),
                child: Image.network(
                  _posterUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Text('Booking ID: $_lastBookingId', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isRegistered ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(isRegistered ? Icons.person : Icons.email, size: 16, color: isRegistered ? Colors.greenAccent : Colors.orangeAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isRegistered ? 'Customer Found ✓ Ticket added to customer account.' : 'Customer not registered. Ticket sent to email.',
                      style: TextStyle(fontSize: 12, color: isRegistered ? Colors.greenAccent : Colors.orangeAccent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Movie: ${widget.showData['movieTitle']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Seats: ${_selectedSeats.join(', ')}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text('Total Amount: ₹$_totalAmount', style: const TextStyle(color: CyberpunkTheme.primaryNeon, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onBack();
            },
            child: const Text('CLOSE'),
          ),
          ElevatedButton.icon(
            onPressed: () => TicketPdfGenerator.printTicket(bookingData, moviePosterUrl: _posterUrl),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('PRINT TICKET'),
            style: ElevatedButton.styleFrom(backgroundColor: CyberpunkTheme.primaryNeon, foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: Seat Selection
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              if (_posterUrl != null)
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        _posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                      // Premium Cinematic Gradient
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black87,
                              Colors.black,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (widget.showData['movieTitle'] ?? 'Movie').toString().toUpperCase(), 
                              style: GoogleFonts.orbitron(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)
                            ),
                            Text(
                              'Screen ${widget.showData['screen']} • ${DateFormat('hh:mm a').format(_showStartTime)}',
                              style: GoogleFonts.poppins(color: CyberpunkTheme.primaryNeon, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: CyberpunkTheme.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('shows').doc(widget.showId).snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            
                            final data = snapshot.data!.data() as Map<String, dynamic>;
                            final seatStatus = data['seatStatus'] as Map<String, dynamic>? ?? {};
                            final seatLayout = data['seatLayout'] as Map<String, dynamic>?;

                            if (seatLayout == null) return const Center(child: Text('Layout Error'));

                            return _buildSeatGrid(seatLayout, seatStatus);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSeatLegend(),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Right: Booking Summary & Payment
        Container(
          width: 400,
          color: CyberpunkTheme.black,
          child: Column(
            children: [
              // Fixed Top Movie Banner in Summary
              Container(
                height: 220,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_posterUrl != null)
                      Image.network(
                        _posterUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            CyberpunkTheme.black.withValues(alpha: 0.7),
                            CyberpunkTheme.black,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: CyberpunkTheme.primaryNeon.withValues(alpha: 0.2),
                              border: Border.all(color: CyberpunkTheme.primaryNeon),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SELECTED SHOW',
                              style: TextStyle(color: CyberpunkTheme.primaryNeon, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.showData['movieTitle']?.toString().toUpperCase() ?? 'MOVIE',
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'Screen ${widget.showData['screen']} • ${DateFormat('hh:mm a').format(_showStartTime)}',
                            style: GoogleFonts.poppins(color: CyberpunkTheme.primaryNeon, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Scrollable Details
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BOOKING SUMMARY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CyberpunkTheme.primaryNeon, letterSpacing: 1)),
                      const SizedBox(height: 24),
                      _summaryItem('Selected Seats', _selectedSeats.isEmpty ? 'None Selected' : _selectedSeats.join(', ')),
                      _summaryItem('Total Amount', '₹$_totalAmount', color: CyberpunkTheme.primaryNeon),
                      const Divider(color: Colors.white10, height: 48),
                      const Text('CUSTOMER DETAILS (OPTIONAL)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildTextField(_nameController, 'Customer Name', Icons.person_outline),
                      const SizedBox(height: 12),
                      _buildTextField(_phoneController, 'Phone Number', Icons.phone_android_outlined),
                      const SizedBox(height: 12),
                      _buildTextField(_emailController, 'Email Address (Optional)', Icons.email_outlined),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10, height: 32),
                      const Text('PAYMENT MODE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildPaymentModes(),
                    ],
                  ),
                ),
              ),

              // Bottom Confirm Button
              Padding(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: (_selectedSeats.isEmpty || _isBooking) ? null : _confirmBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CyberpunkTheme.primaryNeon,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 8,
                      shadowColor: CyberpunkTheme.primaryNeon.withValues(alpha: 0.5),
                    ),
                    child: _isBooking 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text('CONFIRM & GENERATE TICKET', style: GoogleFonts.orbitron(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeatGrid(Map<String, dynamic> layout, Map<String, dynamic> status) {
    final int rows = layout['rows'] ?? 8;
    final List<dynamic> rowSeats = layout['rowSeats'] as List? ?? [];
    final List<dynamic> rowLabels = layout['rowLabels'] ?? [];
    final List<dynamic> rowCategories = layout['rowCategories'] ?? [];
    final int centerAisleAfter = (layout['centerAisleAfter'] ?? 0) as int;
    final int centerAisleWidth = (layout['centerAisleWidth'] ?? 40) as int;
    final int centerAisleRowLimit = (layout['centerAisleRowLimit'] ?? rows) as int;
    final int walkPathAfterRow = (layout['walkPathAfterRow'] ?? 0) as int;
    final int walkPathWidth = (layout['walkPathWidth'] ?? 40) as int;
    final colors = _colorsFromLayout(layout);

    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double availWidth = constraints.maxWidth;
          final rowChildren = <Widget>[];
          for (int rowIndex = 0; rowIndex < rows; rowIndex++) {
            final String rowLabel = rowLabels.length > rowIndex ? rowLabels[rowIndex].toString() : String.fromCharCode(65 + rowIndex);
            final String category = rowCategories.length > rowIndex ? rowCategories[rowIndex].toString() : 'Silver';
            final int seatsInThisRow = rowSeats.length > rowIndex ? int.parse(rowSeats[rowIndex].toString()) : (layout['seatsPerRow'] ?? 10) as int;
            final bool hasAisle = centerAisleAfter > 0 && centerAisleAfter < seatsInThisRow && rowIndex < centerAisleRowLimit;
            final double seatArea = availWidth - 60 - (hasAisle ? centerAisleWidth.toDouble() : 0);
            final double cellSize = (seatArea / seatsInThisRow).clamp(16.0, 40.0);

            rowChildren.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 30, child: Text(rowLabel, style: const TextStyle(color: Colors.white24, fontWeight: FontWeight.bold))),
                    if (!hasAisle) ...List.generate(seatsInThisRow, (colIndex) => _seatChip(rowLabel, colIndex, category, colors, cellSize, status, _selectedSeats)),
                    if (hasAisle) ...[
                      ...List.generate(centerAisleAfter, (colIndex) => _seatChip(rowLabel, colIndex, category, colors, cellSize, status, _selectedSeats)),
                      Container(
                        width: centerAisleWidth.toDouble(), height: cellSize - 8,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white.withValues(alpha: 0.15))),
                        alignment: Alignment.center,
                        child: Text('WALK PATH', style: TextStyle(color: Colors.white24, fontSize: cellSize > 24 ? 8 : 6, letterSpacing: 1)),
                      ),
                      ...List.generate(seatsInThisRow - centerAisleAfter, (colIndex) {
                        final seatNum = centerAisleAfter + colIndex;
                        return _seatChip(rowLabel, seatNum, category, colors, cellSize, status, _selectedSeats);
                      }),
                    ],
                  ],
                ),
              ),
            );

            if (walkPathAfterRow > 0 && rowIndex == walkPathAfterRow - 1) {
              rowChildren.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: Container(
                      width: 220, height: walkPathWidth.toDouble(),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Center(child: Text('WALK PATH', style: TextStyle(color: Colors.white24, fontSize: 9, letterSpacing: 2))),
                    ),
                  ),
                ),
              );
            }
          }

          return Center(
            child: Column(
              children: [
                Container(
                  height: 4, width: availWidth,
                  margin: const EdgeInsets.only(bottom: 48),
                  decoration: BoxDecoration(
                    color: CyberpunkTheme.primaryNeon.withValues(alpha: 0.5),
                    boxShadow: [BoxShadow(color: CyberpunkTheme.primaryNeon.withValues(alpha: 0.3), blurRadius: 10)]
                  ),
                ),
                ...rowChildren,
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, Color> _colorsFromLayout(Map<String, dynamic>? layout) {
    final colors = <String, Color>{
      'Platinum': const Color(0xFFFF5F00),
      'Gold': const Color(0xFFFFD700),
      'Silver': const Color(0xFF78909C),
      'Recliner': const Color(0xFF00E5FF),
    };
    final saved = layout?['categoryColors'] as Map?;
    if (saved != null) {
      saved.forEach((key, value) {
        final intVal = int.tryParse(value.toString());
        if (intVal != null) colors[key.toString()] = Color(intVal);
      });
    }
    return colors;
  }

  Widget _seatChip(String rowLabel, int colIndex, String category, Map<String, Color> colors, double cellSize, Map<String, dynamic> status, List<String> selectedSeats) {
    final seatId = '$rowLabel${colIndex + 1}';
    final currentStatus = status[seatId] ?? 'available';
    final isSelected = selectedSeats.contains(seatId);

    Color color = colors[category] ?? Colors.greenAccent;
    if (currentStatus == 'booked') color = Colors.redAccent;
    if (currentStatus == 'blocked') color = Colors.amber;
    if (isSelected) color = CyberpunkTheme.primaryNeon;

    return InkWell(
      onTap: (currentStatus == 'booked' || currentStatus == 'blocked') ? null : () {
        setState(() {
          if (isSelected) {
            _selectedSeats.remove(seatId);
          } else {
            _selectedSeats.add(seatId);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: cellSize - 8, height: cellSize - 8,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text('${colIndex + 1}', style: TextStyle(fontSize: cellSize > 24 ? 10 : 8, color: isSelected ? Colors.black : color, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSeatLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 12,
      children: [
        _legendItem('Selected', CyberpunkTheme.primaryNeon),
        _legendItem('Booked', Colors.redAccent),
        _legendItem('Blocked', Colors.amber),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color.withValues(alpha: 0.2), border: Border.all(color: color), borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _summaryItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white24, size: 20),
        filled: true,
        fillColor: CyberpunkTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildPaymentModes() {
    final modes = ['Cash', 'UPI', 'Card', 'Other'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modes.map((mode) {
        final isSelected = _paymentMode == mode;
        return InkWell(
          onTap: () => setState(() => _paymentMode = mode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? CyberpunkTheme.primaryNeon : CyberpunkTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? CyberpunkTheme.primaryNeon : Colors.white10),
            ),
            child: Text(
              mode,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
