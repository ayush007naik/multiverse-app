import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_compat/db_compat.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/cyberpunk_theme.dart';
import '../../utils/ticket_pdf_generator.dart';
import '../../services/theatre_service.dart';

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key});

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theatreService = Provider.of<TheatreService>(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('BOOKING MANAGEMENT', style: Theme.of(context).textTheme.titleLarge),
              Row(
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search Ticket, Booking ID, or Phone',
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: CyberpunkTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.toLowerCase();
                        });
                      },
                    ),
                  ),

                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: CyberpunkTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: theatreService.getBookings(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.primaryNeon));
                  }
                  
                  var bookings = snapshot.data?.docs ?? [];
                  
                  // Filter locally
                  if (_searchQuery.isNotEmpty) {
                    bookings = bookings.where((b) {
                      final data = b.data();
                      final ticketNo = (data['ticketNumber'] ?? '').toString().toLowerCase();
                      final bookingId = (data['bookingId'] ?? b.id).toString().toLowerCase();
                      final phone = (data['customerPhone'] ?? '').toString().toLowerCase();
                      return ticketNo.contains(_searchQuery) || bookingId.contains(_searchQuery) || phone.contains(_searchQuery);
                    }).toList();
                  }

                  if (bookings.isEmpty) {
                    return const Center(child: Text('No bookings found.', style: TextStyle(color: Colors.white54)));
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 24,
                        headingTextStyle: const TextStyle(color: CyberpunkTheme.primaryNeon, fontWeight: FontWeight.bold),
                        columns: const [
                          DataColumn(label: Text('TICKET NO.')),
                          DataColumn(label: Text('BOOKING ID')),
                          DataColumn(label: Text('CUSTOMER')),
                          DataColumn(label: Text('PHONE')),
                          DataColumn(label: Text('MOVIE')),
                          DataColumn(label: Text('TIME')),
                          DataColumn(label: Text('SEATS')),
                          DataColumn(label: Text('PAID')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('BOOKED AT')),
                          DataColumn(label: Text('ACTIONS')),
                        ],
                        rows: bookings.map((b) {
                          final data = b.data();
                          final isUsed = data['isUsed'] == true;
                          final bStatus = (data['bookingStatus'] ?? data['status'] ?? 'pending').toString().toLowerCase();
                          final isOffline = data['isOffline'] == true;
                          
                          String displayStatus = 'BOOKED';
                          if (bStatus == 'cancelled') {
                            displayStatus = 'CANCELLED';
                          } else if (isUsed) {
                            displayStatus = 'USED';
                          } else if (bStatus == 'pending') {
                            displayStatus = 'PENDING';
                          } else if (bStatus == 'confirmed' || bStatus == 'success') {
                            displayStatus = 'BOOKED';
                          } else {
                            displayStatus = bStatus.toUpperCase();
                          }

                          return DataRow(cells: [
                            DataCell(Text(data['ticketNumber'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text((data['bookingId'] ?? b.id).substring(0, 12) + '...', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white54))),
                            DataCell(Text(data['customerName'] ?? data['userName'] ?? '-')),
                            DataCell(Text(data['customerPhone'] ?? '-')),
                            DataCell(Text(data['movieName'] ?? data['movieTitle'] ?? '-')),
                            DataCell(Text(data['showTime'] ?? '-')),
                            DataCell(Text((data['seats'] as List? ?? []).join(', '))),
                            DataCell(Text('₹${data['totalPaid'] ?? data['finalAmount'] ?? data['totalAmount'] ?? 0}')),
                            DataCell(_buildStatusChip(displayStatus)),
                            DataCell(Text(_formatBookedAt(data))),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (bStatus != 'cancelled')
                                  IconButton(
                                    icon: const Icon(Icons.send_rounded, color: CyberpunkTheme.primaryNeon, size: 20),
                                    onPressed: () => _showResendNotificationDialog(context, theatreService, b.id, data),
                                    tooltip: 'Resend Ticket',
                                  ),
                                if (isOffline && bStatus != 'cancelled')
                                  IconButton(
                                    icon: const Icon(Icons.print, color: CyberpunkTheme.accentNeon, size: 20),
                                    onPressed: () => TicketPdfGenerator.printTicket(data, moviePosterUrl: data['moviePoster']),
                                    tooltip: 'Reprint Ticket',
                                  ),
                                if (bStatus != 'cancelled')
                                  IconButton(
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                                    onPressed: () => _showCancelConfirmation(context, theatreService, b.id, data),
                                    tooltip: 'Cancel Booking',
                                  ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBookedAt(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate().toLocal());
    }
    final bookingTime = data['bookingTime'] ?? data['bookedAt'];
    if (bookingTime is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(bookingTime.toDate().toLocal());
    }
    final bookingDate = data['bookingDate'] ?? data['date'];
    final time = data['bookingTime'] ?? data['bookedAt'];
    if (bookingDate is String && time is String && time.isNotEmpty) {
      return '$bookingDate • $time';
    }
    return '-';
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.amber;
    if (status == 'BOOKED') color = Colors.greenAccent;
    if (status == 'USED') color = Colors.blueAccent;
    if (status == 'CANCELLED') color = Colors.redAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context, TheatreService service, String bookingId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CyberpunkTheme.surface,
        title: const Text('CANCEL BOOKING?'),
        content: Text('Are you sure you want to cancel the booking for ${data['movieTitle']}?\nSeats: ${(data['seats'] as List).join(', ')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('KEEP IT', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // For offline bookings, we also need to free the seats in the show document
                if (data['isOffline'] == true) {
                  final showId = data['showId'];
                  final seats = List<String>.from(data['seats'] ?? []);
                  
                  await FirebaseFirestore.instance.runTransaction((transaction) async {
                    final showRef = FirebaseFirestore.instance.collection('shows').doc(showId);
                    final showSnap = await transaction.get(showRef);
                    if (!showSnap.exists) return;
                    
                    final showData = showSnap.data() as Map<String, dynamic>;
                    final seatStatus = Map<String, dynamic>.from(showData['seatStatus'] ?? {});
                    
                    for (var seatId in seats) {
                      if (seatStatus[seatId] == 'booked') {
                        seatStatus[seatId] = 'available';
                      }
                    }
                    
                    int availableSeats = (showData['availableSeats'] ?? 0) + seats.length;
                    
                    transaction.update(showRef, {
                      'seatStatus': seatStatus,
                      'availableSeats': availableSeats,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    
                    transaction.update(FirebaseFirestore.instance.collection('movie_bookings').doc(bookingId), {
                      'status': 'cancelled',
                      'bookingStatus': 'cancelled',
                      'cancelledAt': FieldValue.serverTimestamp(),
                    });
                  });
                } else {
                  await service.cancelBooking(bookingId, data);
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking cancelled successfully'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('CANCEL BOOKING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showResendNotificationDialog(BuildContext context, TheatreService service, String bookingId, Map<String, dynamic> data) {
    String selectedChannel = 'whatsapp';
    final phone = (data['customerPhone'] ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    final email = data['customerEmail'] ?? '';
    final customerName = data['customerName'] ?? data['userName'] ?? 'Customer';
    final movieName = data['movieName'] ?? data['movieTitle'] ?? '';
    final seats = (data['seats'] as List? ?? []).join(', ');
    final showTime = data['showTime'] ?? '';
    final ticketNo = data['ticketNumber'] ?? '';

    final ticketMessage = 'Hi $customerName,\nYour ticket for *$movieName* is confirmed.\nTicket: $ticketNo\nSeats: $seats\nShow Time: $showTime\n\nThank you for booking with us!';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: CyberpunkTheme.surface,
          title: const Text('RESEND TICKET', style: TextStyle(color: CyberpunkTheme.primaryNeon)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('WhatsApp', style: TextStyle(color: Colors.white)),
                value: 'whatsapp',
                groupValue: selectedChannel,
                activeColor: CyberpunkTheme.primaryNeon,
                onChanged: (v) => setState(() => selectedChannel = v ?? 'whatsapp'),
              ),
              RadioListTile<String>(
                title: const Text('Email', style: TextStyle(color: Colors.white)),
                value: 'email',
                groupValue: selectedChannel,
                activeColor: CyberpunkTheme.primaryNeon,
                onChanged: (v) => setState(() => selectedChannel = v ?? 'whatsapp'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await service.resendNotification(
                    bookingId,
                    sms: false,
                    whatsapp: selectedChannel == 'whatsapp',
                    email: selectedChannel == 'email',
                  );

                  if (selectedChannel == 'whatsapp' && phone.isNotEmpty) {
                    String? pdfUrl;
                    try {
                      final pdfBytes = await TicketPdfGenerator.generateTicket(
                        booking: data,
                        moviePosterUrl: data['moviePoster'],
                      );
                      final ref = FirebaseStorage.instance.ref().child('tickets/$bookingId.pdf');
                      await ref.putData(pdfBytes, const SettableMetadata(contentType: 'application/pdf'));
                      pdfUrl = await ref.getDownloadURL();
                    } catch (_) {}
                    final msg = pdfUrl != null ? '$ticketMessage\n\nDownload Ticket: $pdfUrl' : ticketMessage;
                    final whatsappUrl = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
                    if (await canLaunchUrl(whatsappUrl)) {
                      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                    }
                  } else if (selectedChannel == 'email' && email.isNotEmpty) {
                    String? pdfUrl;
                    try {
                      final pdfBytes = await TicketPdfGenerator.generateTicket(
                        booking: data,
                        moviePosterUrl: data['moviePoster'],
                      );
                      final ref = FirebaseStorage.instance.ref().child('tickets/$bookingId.pdf');
                      await ref.putData(pdfBytes, const SettableMetadata(contentType: 'application/pdf'));
                      pdfUrl = await ref.getDownloadURL();
                    } catch (_) {}
                    final mailtoUrl = Uri(
                      scheme: 'mailto',
                      path: email,
                      query: 'subject=${Uri.encodeComponent("Your Ticket - $movieName")}&body=${Uri.encodeComponent(pdfUrl != null ? '$ticketMessage\n\nDownload Ticket: $pdfUrl' : ticketMessage)}',
                    );
                    if (await canLaunchUrl(mailtoUrl)) {
                      await launchUrl(mailtoUrl);
                    }
                  }

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification resend triggered'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: CyberpunkTheme.primaryNeon),
              child: const Text('RESEND NOW', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
