import 'dart:async';

import 'package:db_compat/db_compat.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/logging_service.dart';
import 'movie_ticket_screen.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  bool _isLinking = false;
  StreamSubscription<QuerySnapshot>? _userIdSub;
  StreamSubscription<QuerySnapshot>? _customerUidSub;
  List<QueryDocumentSnapshot> _bookings = [];
  final ValueNotifier<List<QueryDocumentSnapshot>> _bookingsNotifier =
      ValueNotifier([]);
  QuerySnapshot? _userIdSnap;
  QuerySnapshot? _customerUidSnap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToBookings();
      _linkPhoneBookingsWithRetry();
    });
  }

  @override
  void dispose() {
    _userIdSub?.cancel();
    _customerUidSub?.cancel();
    _bookingsNotifier.dispose();
    super.dispose();
  }

  void _subscribeToBookings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userIdSub = FirebaseFirestore.instance
        .collection('movie_bookings')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (snap) {
            _userIdSnap = snap;
            _emitMerged();
          },
          onError: (e) {
            Log.e('MyTicketsScreen', '[MyTickets] userId query error: $e');
            _userIdSnap = null;
            _emitMerged();
          },
        );

    _customerUidSub = FirebaseFirestore.instance
        .collection('movie_bookings')
        .where('customerUid', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (snap) {
            _customerUidSnap = snap;
            _emitMerged();
          },
          onError: (e) {
            Log.e('MyTicketsScreen', '[MyTickets] customerUid query error: $e');
            _customerUidSnap = null;
            _emitMerged();
          },
        );
  }

  void _emitMerged() {
    final merged = <String, QueryDocumentSnapshot>{};
    if (_userIdSnap != null) {
      for (final doc in _userIdSnap!.docs) {
        merged[doc.id] = doc;
      }
    }
    if (_customerUidSnap != null) {
      for (final doc in _customerUidSnap!.docs) {
        merged[doc.id] = doc;
      }
    }
    _bookings = merged.values.toList();
    _bookingsNotifier.value = _bookings;
  }

  Future<void> _linkPhoneBookingsWithRetry() async {
    await _linkPhoneBookings();
    if (mounted && _bookings.isEmpty && !_isLinking) {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        await _linkPhoneBookings();
      }
    }
  }

  Future<void> _linkPhoneBookings({bool showFeedback = false}) async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isLinking) return;

    setState(() => _isLinking = true);

    try {
      String? phone = user.phoneNumber;
      String? email = user.email;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data();
        phone ??= data?['phone']?.toString();
        email ??= data?['email']?.toString();
      }

      if (phone == null || phone.length < 10) {
        Log.i('MyTicketsScreen', '[MyTickets] No phone number found for user linking');
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No phone number found to link bookings'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final digits = phone.replaceAll(RegExp(r'\D'), '');
      final normalized = digits.length > 10
          ? digits.substring(digits.length - 10)
          : digits;

      Log.i('MyTicketsScreen', '[MyTickets] Attempting to link bookings for: $normalized');

      final params = <String, dynamic>{'phone': normalized};
      if (email != null && email.isNotEmpty) {
        params['email'] = email.toLowerCase().trim();
      }

      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final result = await functions
          .httpsCallable('linkCustomerBookings')
          .call(params);

      final linkedCount =
          (result.data as Map<String, dynamic>?)?['linked'] ?? 0;
      Log.i('MyTicketsScreen', '[MyTickets] Linked $linkedCount bookings');

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              linkedCount > 0
                  ? 'Linked $linkedCount booking(s) to your account'
                  : 'All bookings already linked',
            ),
            backgroundColor: linkedCount > 0
                ? const Color(0xFF4CAF50)
                : Colors.grey[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Log.e('MyTicketsScreen', '[MyTickets] Phone linking error: $e');
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to link bookings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLinking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'MY TICKETS',
          style: GoogleFonts.orbitron(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLinking)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF7A1A),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              onPressed: () => _linkPhoneBookings(showFeedback: true),
              tooltip: 'Sync bookings',
            ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7A1A), Color(0xFFFF512F)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
                tabs: const [
                  Tab(text: 'UPCOMING'),
                  Tab(text: 'PAST'),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Refresh with ',
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.sync_rounded,
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    size: 14,
                  ),
                  Text(
                    ' to see latest tickets',
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTicketsList(showUpcoming: true),
                  _buildTicketsList(showUpcoming: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsList({required bool showUpcoming}) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 80,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 20),
            Text(
              'Please login to view tickets',
              style: GoogleFonts.orbitron(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<List<QueryDocumentSnapshot>>(
      valueListenable: _bookingsNotifier,
      builder: (context, docs, _) {
        docs.sort((a, b) {
          final aTime =
              (a.data())['createdAt'] as Timestamp?;
          final bTime =
              (b.data())['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty && _isLinking) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFFFF7A1A)),
                SizedBox(height: 16),
                Text(
                  'Syncing your bookings...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          );
        }

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF7A1A).withValues(alpha: 0.2),
                          const Color(0xFFFF7A1A).withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.movie_creation_outlined,
                      size: 100,
                      color: const Color(0xFFFF7A1A).withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'No Movie Bookings Yet',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Book your first movie ticket or sync counter bookings!',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () => _linkPhoneBookings(showFeedback: true),
                    icon: const Icon(Icons.sync_rounded, size: 20),
                    label: Text(
                      'SYNC BOOKINGS',
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A1A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final now = DateTime.now();
        final filteredBookings = docs.where((doc) {
          final data = doc.data();
          String? dateStr = data['date'] as String?;
          dateStr ??= data['showDate'] as String?;
          dateStr ??= data['bookingDate'] as String?;

          if (dateStr == null) {
            final showTime = data['showTime'] as String?;
            if (showTime != null && showTime.contains('•')) {
              try {
                final parsed = DateFormat(
                  'dd MMM yyyy • hh:mm a',
                ).parse(showTime);
                dateStr = DateFormat('yyyy-MM-dd').format(parsed);
              } catch (_) {}
            }
          }

          if (dateStr == null) return false;

          try {
            final bookingDate = DateTime.parse(dateStr);

            String? timeStr = data['time'] as String?;
            timeStr ??= data['showTime'] as String?;
            if (timeStr != null && timeStr.contains('•')) {
              timeStr = timeStr.split('•').last.trim();
            }

            DateTime startDateTime = DateTime(
              bookingDate.year,
              bookingDate.month,
              bookingDate.day,
            );

            if (timeStr != null) {
              for (final fmt in ['hh:mm a', 'h:mm a', 'HH:mm', 'H:mm']) {
                try {
                  final parsedTime = DateFormat(fmt).parse(timeStr);
                  startDateTime = DateTime(
                    bookingDate.year,
                    bookingDate.month,
                    bookingDate.day,
                    parsedTime.hour,
                    parsedTime.minute,
                  );
                  break;
                } catch (_) {}
              }
            }

            int durationMinutes = 150;
            try {
              if (data['movieData'] is Map) {
                final movieData = data['movieData'] as Map<String, dynamic>;
                final d = movieData['duration'] as String?;
                if (d != null) {
                  final h = RegExp(r'(\d+)\s*h').firstMatch(d);
                  final m = RegExp(r'(\d+)\s*m').firstMatch(d);
                  final hours = h != null ? int.parse(h.group(1)!) : 0;
                  final mins = m != null ? int.parse(m.group(1)!) : 0;
                  if (hours > 0 || mins > 0) {
                    durationMinutes = hours * 60 + mins;
                  }
                }
              }
            } catch (_) {}

            final endDateTime = startDateTime.add(
              Duration(minutes: durationMinutes),
            );

            return showUpcoming
                ? now.isBefore(endDateTime)
                : !now.isBefore(endDateTime);
          } catch (e) {
            return false;
          }
        }).toList();

        if (filteredBookings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    showUpcoming
                        ? Icons.event_busy_rounded
                        : Icons.history_rounded,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    showUpcoming ? 'No Upcoming Shows' : 'No Past Shows',
                    style: GoogleFonts.orbitron(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    showUpcoming
                        ? 'Book a new movie to see it here'
                        : 'Your watched movies will appear here',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _linkPhoneBookings(showFeedback: true);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredBookings.length,
            itemBuilder: (context, index) {
              final booking =
                  filteredBookings[index].data();
              final bookingId = filteredBookings[index].id;
              return _buildTicketCard(context, booking, bookingId);
            },
          ),
        );
      },
    );
  }

  Widget _buildTicketCard(
    BuildContext context,
    Map<String, dynamic> booking,
    String bookingId,
  ) {
    final movieName = booking['movieName'] ?? booking['movieTitle'] ?? 'Movie';
    final theatreName = booking['theatreName'] ?? 'Cinema';
    final date = booking['date'] ?? booking['showDate'] ?? 'Date not set';
    final time =
        booking['time'] ??
        (booking['showTime']?.toString().contains('•') == true
            ? booking['showTime'].toString().split('•').last.trim()
            : booking['showTime']) ??
        'Time not set';
    final seats = booking['seats'] as List<dynamic>? ?? [];
    final totalAmount = (booking['totalAmount'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF7A1A).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A1A).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MovieTicketScreen(bookingData: booking),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7A1A), Color(0xFFFF512F)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.movie_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movieName,
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            theatreName,
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                _buildDetailRow(Icons.calendar_today_rounded, 'Date', date),
                const SizedBox(height: 10),
                _buildDetailRow(Icons.access_time_rounded, 'Time', time),
                const SizedBox(height: 10),
                _buildDetailRow(
                  Icons.event_seat_rounded,
                  'Seats',
                  seats.join(', '),
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  Icons.currency_rupee_rounded,
                  'Total',
                  '₹${totalAmount.toStringAsFixed(0)}',
                  isHighlight: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MovieTicketScreen(bookingData: booking),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_rounded, size: 20),
                    label: Text(
                      'VIEW TICKET',
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A1A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Booking ID: $bookingId',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF7A1A), size: 18),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: isHighlight ? const Color(0xFFFF7A1A) : Colors.white,
              fontSize: isHighlight ? 15 : 13,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
