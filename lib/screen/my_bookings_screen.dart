import 'dart:async';
import 'dart:io';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/app_constants.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../core/logging_service.dart';

/// My Bookings Screen - Shows bookings from BOTH collections:
/// - service_bookings (from service_booking_form_screen, field: customerId)
/// - appointments (from service_detail_screen_v2, field: userId)
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  StreamSubscription<QuerySnapshot>? _serviceBookingsSub;
  StreamSubscription<QuerySnapshot>? _appointmentsSub;
  final _controller = StreamController<List<DocumentSnapshot>>();
  List<DocumentSnapshot> _serviceBookingsDocs = [];
  List<DocumentSnapshot> _appointmentsDocs = [];

  // Cache for provider details: partnerId -> provider data
  final Map<String, Map<String, dynamic>> _providerCache = {};
  final Set<String> _fetchingProviders = {};

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Auto-migrate existing pending bookings to confirmed
    _migrateExistingBookings(uid);

    // Listen to service_bookings collection
    _serviceBookingsSub = FirebaseFirestore.instance
        .collection('service_bookings')
        .where('customerId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            _serviceBookingsDocs = snapshot.docs;
            _emitMerged();
          },
          onError: (e) {
            Log.e('MyBookingsScreen', 'service_bookings stream error: $e');
          },
        );

    // Listen to appointments collection
    _appointmentsSub = FirebaseFirestore.instance
        .collection('appointments')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            _appointmentsDocs = snapshot.docs;
            _emitMerged();
            // Fetch provider details for all bookings
            _fetchAllProviderDetails();
          },
          onError: (e) {
            Log.e('MyBookingsScreen', 'appointments stream error: $e');
          },
        );
  }

  /// Fetch provider details for all bookings that have partnerId/serviceId
  void _fetchAllProviderDetails() {
    final allDocs = [..._serviceBookingsDocs, ..._appointmentsDocs];
    for (final doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final partnerId = (data['partnerId'] ?? '').toString();
      if (partnerId.isNotEmpty &&
          !_providerCache.containsKey(partnerId) &&
          !_fetchingProviders.contains(partnerId)) {
        _fetchProviderDetails(partnerId);
      }
    }
  }

  /// Fetch a single provider's details from Firestore 'partners' collection
  Future<void> _fetchProviderDetails(String partnerId) async {
    if (_fetchingProviders.contains(partnerId)) return;
    _fetchingProviders.add(partnerId);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('partners')
          .doc(partnerId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        data['id'] = doc.id;
        setState(() {
          _providerCache[partnerId] = data;
        });
      }
    } catch (e) {
      Log.e('MyBookingsScreen', 'Error fetching provider $partnerId: $e');
    } finally {
      _fetchingProviders.remove(partnerId);
    }
  }

  /// One-time migration: auto-confirm existing pending bookings + embed provider details
  Future<void> _migrateExistingBookings(String uid) async {
    try {
      // Fix service_bookings with pending status
      final pendingServiceBookings = await FirebaseFirestore.instance
          .collection('service_bookings')
          .where('customerId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in pendingServiceBookings.docs) {
        final data = doc.data();
        final updateData = <String, dynamic>{'status': 'confirmed'};
        if (data['providerName'] == null ||
            data['providerName'].toString().isEmpty) {
          updateData['providerName'] =
              data['serviceCategory'] ?? 'Service Provider';
        }
        // Embed provider details if partnerId exists but providerDetails doesn't
        if (data['providerDetails'] == null &&
            data['partnerId'] != null &&
            data['partnerId'].toString().isNotEmpty) {
          final partnerData = await _fetchPartnerDataOnce(
            data['partnerId'].toString(),
          );
          if (partnerData != null) updateData['providerDetails'] = partnerData;
        }
        await doc.reference.update(updateData);
      }

      // Fix appointments with pending status
      final pendingAppointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in pendingAppointments.docs) {
        final data = doc.data();
        final updateData = <String, dynamic>{'status': 'confirmed'};
        if (data['providerName'] == null ||
            data['providerName'].toString().isEmpty) {
          updateData['providerName'] =
              data['serviceName'] ?? 'Service Provider';
        }
        // Embed provider details if partnerId exists but providerDetails doesn't
        if (data['providerDetails'] == null &&
            data['partnerId'] != null &&
            data['partnerId'].toString().isNotEmpty) {
          final partnerData = await _fetchPartnerDataOnce(
            data['partnerId'].toString(),
          );
          if (partnerData != null) updateData['providerDetails'] = partnerData;
        }
        await doc.reference.update(updateData);
      }

      Log.i(
        'MyBookingsScreen',
        'Migrated ${pendingServiceBookings.docs.length} service_bookings + ${pendingAppointments.docs.length} appointments to confirmed',
      );
    } catch (e) {
      Log.e('MyBookingsScreen', 'Migration error (non-critical): $e');
    }
  }

  /// Helper to fetch and structure partner data for embedding
  Future<Map<String, dynamic>?> _fetchPartnerDataOnce(String partnerId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('partners')
          .doc(partnerId)
          .get();
      if (!doc.exists) return null;
      final d = doc.data()!;
      return {
        'name': d['name'] ?? '',
        'qualification': d['qualification'] ?? '',
        'specialization':
            d['specialization'] ??
            (d['selectedSubCategories'] as List?)?.join(', ') ??
            '',
        'category': d['category'] ?? '',
        'experience': d['experience'] ?? d['yearsOfExperience'] ?? '',
        'rating': d['rating'] ?? '',
        'shopAddress': d['shopAddress'] ?? d['address'] ?? '',
        'phone': d['phone'] ?? '',
        'bio': d['bio'] ?? '',
        'profileImage': d['profileImage'] ?? d['image'] ?? '',
      };
    } catch (e) {
      Log.e('MyBookingsScreen', 'Error fetching partner for migration: $e');
      return null;
    }
  }

  void _emitMerged() {
    final all = [..._serviceBookingsDocs, ..._appointmentsDocs];
    // Sort client-side by timestamp descending
    all.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aTime = aData['createdAt'] ?? aData['timestamp'];
      final bTime = bData['createdAt'] ?? bData['timestamp'];
      if (aTime == null || bTime == null) return 0;
      return (bTime as Timestamp).compareTo(aTime as Timestamp);
    });
    if (!_controller.isClosed) {
      _controller.add(all);
    }
  }

  @override
  void dispose() {
    _serviceBookingsSub?.cancel();
    _appointmentsSub?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'MY BOOKINGS',
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
      ),
      body: _buildBookingsList(),
    );
  }

  Widget _buildBookingsList() {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Center(
        child: Text(
          'Please login to view your bookings',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _controller.stream,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoading();
        }

        // Error state
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error);
        }

        // Empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(context);
        }

        final bookings = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            // Re-trigger both streams
            setState(() {});
          },
          color: const Color(0xFFFF7A1A),
          backgroundColor: Colors.black,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index].data() as Map<String, dynamic>;
              final bookingId = bookings[index].id;
              return _buildBookingCard(booking, bookingId);
            },
          ),
        );
      },
    );
  }

  /// Shimmer loading animation
  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFF7A1A),
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }

  /// User-friendly error state
  Widget _buildErrorState(dynamic error) {
    final errorString = error.toString().toLowerCase();
    String userMessage = 'Unable to load bookings';
    String? actionHint;

    if (errorString.contains('index') ||
        errorString.contains('failed-precondition')) {
      userMessage = 'Unable to load bookings';
      actionHint =
          'Database index is being created. Please try again in 2-3 minutes.';
    } else if (errorString.contains('permission') ||
        errorString.contains('unauthorized')) {
      userMessage = 'Access denied';
      actionHint = 'Please contact support for assistance.';
    } else if (errorString.contains('network') ||
        errorString.contains('unavailable')) {
      userMessage = 'No internet connection';
      actionHint = 'Please check your network and try again.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 80,
              color: Colors.red.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            Text(
              userMessage,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionHint != null) ...[
              const SizedBox(height: 12),
              Text(
                actionHint,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'RETRY',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A1A),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty state with "Book a Service" button
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 100,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 24),
            Text(
              'No bookings yet',
              style: GoogleFonts.orbitron(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Book your first service to get started',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'BOOK A SERVICE',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A1A),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, String bookingId) {
    // Normalize fields from both collections
    final serviceName =
        booking['serviceCategory'] ?? booking['serviceName'] ?? 'Service';
    final status = booking['status'] ?? 'pending';
    final budget =
        (booking['budget'] ?? booking['price'] as num?)?.toDouble() ?? 0;
    final scheduledTime = booking['scheduledTime'] ?? booking['time'] ?? '';
    final problem = booking['serviceDescription'] ?? booking['problem'] ?? '';

    // Get provider details from cache or embedded providerDetails
    final partnerId = (booking['partnerId'] ?? '').toString();
    final embeddedProvider =
        booking['providerDetails'] as Map<String, dynamic>?;
    final providerData = partnerId.isNotEmpty
        ? _providerCache[partnerId]
        : null;
    // Merge: prefer fetched data, fallback to embedded
    final effectiveProvider = providerData ?? embeddedProvider;

    // Provider fields - prefer fetched data, fallback to embedded, then booking fields
    final providerName =
        effectiveProvider?['name'] ?? booking['providerName'] ?? serviceName;
    final providerQualification = (effectiveProvider?['qualification'] ?? '')
        .toString();
    final providerSpecialty =
        (effectiveProvider?['specialization'] ??
                effectiveProvider?['specialty'] ??
                (effectiveProvider?['selectedSubCategories'] as List?)?.join(
                  ', ',
                ) ??
                '')
            .toString();
    final providerCategory = (effectiveProvider?['category'] ?? '').toString();
    final providerExperience =
        (effectiveProvider?['experience'] ??
                effectiveProvider?['yearsOfExperience'] ??
                '')
            .toString();
    final providerRating = (effectiveProvider?['rating'] ?? '').toString();
    final providerAddress =
        (effectiveProvider?['shopAddress'] ??
                effectiveProvider?['address'] ??
                effectiveProvider?['business_address'] ??
                '')
            .toString();
    final providerPhone = (effectiveProvider?['phone'] ?? '').toString();
    final providerBio = (effectiveProvider?['bio'] ?? '').toString();
    final providerImage =
        (effectiveProvider?['profileImage'] ??
                effectiveProvider?['image'] ??
                '')
            .toString();

    // Handle date from both collections (Timestamp or String)
    final scheduledDate = _parseDate(booking);

    final statusInfo = _getStatusInfo(status);

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
          color: statusInfo.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusInfo.color.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showBookingPreviewSheet(booking, bookingId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Service name + Status badge
                Row(
                  children: [
                    // Provider avatar
                    _buildProviderAvatar(
                      providerImage,
                      providerName,
                      statusInfo,
                    ),
                    const SizedBox(width: 12),
                    // Service details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            providerName.toString(),
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            serviceName,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFF7A1A),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    _buildStatusBadge(status, statusInfo),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: Colors.white24, height: 1),

                // ── PROVIDER DETAILS SECTION ──
                if (effectiveProvider != null || partnerId.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildProviderDetailsSection(
                    providerName: providerName.toString(),
                    qualification: providerQualification,
                    specialty: providerSpecialty,
                    category: providerCategory,
                    experience: providerExperience,
                    rating: providerRating,
                    address: providerAddress,
                    phone: providerPhone,
                    bio: providerBio,
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white24, height: 1),
                ],

                const SizedBox(height: 14),

                // Booking details grid
                _buildDetailRow(
                  Icons.calendar_today_rounded,
                  'Date',
                  scheduledDate != null
                      ? _formatDate(scheduledDate)
                      : 'Not set',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.access_time_rounded,
                  'Time',
                  scheduledTime.isNotEmpty
                      ? scheduledTime.toString()
                      : 'Not set',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.currency_rupee_rounded,
                  'Budget',
                  'Rs. ${budget.toStringAsFixed(0)}',
                ),
                if (problem.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.description_outlined,
                    'Details',
                    problem.toString(),
                  ),
                ],

                const SizedBox(height: 12),

                // Action Buttons Row
                Row(
                  children: [
                    // Download PDF Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showBookingPreviewSheet(booking, bookingId),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: Text(
                          'DOWNLOAD PDF',
                          style: GoogleFonts.orbitron(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF7A1A),
                          side: const BorderSide(color: Color(0xFFFF7A1A)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Booking ID
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

  /// Parse date from either collection
  DateTime? _parseDate(Map<String, dynamic> booking) {
    // From service_bookings: scheduledDate is a Timestamp
    if (booking['scheduledDate'] is Timestamp) {
      return (booking['scheduledDate'] as Timestamp).toDate();
    }
    // From appointments: bookingDate or date is a string "yyyy-MM-dd"
    final dateStr = booking['bookingDate'] ?? booking['date'];
    if (dateStr is String && dateStr.isNotEmpty) {
      try {
        return DateTime.parse(dateStr);
      } catch (_) {}
    }
    return null;
  }

  Widget _buildStatusBadge(String status, StatusInfo statusInfo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusInfo.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusInfo.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        statusInfo.label,
        style: GoogleFonts.poppins(
          color: statusInfo.color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF7A1A), size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Provider avatar circle with image or initials
  Widget _buildProviderAvatar(
    String imageUrl,
    String name,
    StatusInfo statusInfo,
  ) {
    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _buildInitialsAvatar(name, statusInfo),
        ),
      );
    }
    return _buildInitialsAvatar(name, statusInfo);
  }

  Widget _buildInitialsAvatar(String name, StatusInfo statusInfo) {
    final initials = name.isNotEmpty
        ? name
              .split(' ')
              .take(2)
              .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
              .join('')
        : '?';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: statusInfo.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.orbitron(
            color: statusInfo.color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  /// Full provider details card section
  Widget _buildProviderDetailsSection({
    required String providerName,
    required String qualification,
    required String specialty,
    required String category,
    required String experience,
    required String rating,
    required String address,
    required String phone,
    required String bio,
  }) {
    final hasDetails =
        qualification.isNotEmpty ||
        specialty.isNotEmpty ||
        address.isNotEmpty ||
        experience.isNotEmpty;

    if (!hasDetails) {
      // Minimal provider info - just show category badge if available
      if (category.isNotEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFF7A1A).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFFF7A1A).withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            category,
            style: GoogleFonts.poppins(
              color: const Color(0xFFFF7A1A),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF7A1A).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              const Icon(
                Icons.medical_information_rounded,
                color: Color(0xFFFF7A1A),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'SERVICE PROVIDER',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFFFF7A1A),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Qualification
          if (qualification.isNotEmpty)
            _buildProviderInfoLine(Icons.school_rounded, qualification),

          // Specialty / Specialization
          if (specialty.isNotEmpty)
            _buildProviderInfoLine(
              Icons.star_rounded,
              specialty,
              isAccent: true,
            ),

          // Category badge
          if (category.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFFF7A1A).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                category,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFF7A1A),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],

          // Experience
          if (experience.isNotEmpty)
            _buildProviderInfoLine(
              Icons.work_rounded,
              '$experience years experience',
            ),

          // Rating
          if (rating.isNotEmpty && rating != '0' && rating != '0.0') ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$rating / 5.0',
                  style: GoogleFonts.poppins(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          // Address (clinic/shop address)
          if (address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFFFF7A1A),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Phone
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.phone_rounded,
                  color: Color(0xFFFF7A1A),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  phone,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],

          // Bio
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              bio,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderInfoLine(
    IconData icon,
    String text, {
    bool isAccent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: isAccent ? const Color(0xFFFF7A1A) : Colors.white54,
            size: 15,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: isAccent
                    ? const Color(0xFFFF7A1A)
                    : Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: isAccent ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return StatusInfo(
          label: 'Pending',
          color: Colors.orange,
          icon: Icons.pending_rounded,
        );
      case 'offers_incoming':
        return StatusInfo(
          label: 'Waiting for Offers',
          color: Colors.blue,
          icon: Icons.hourglass_empty_rounded,
        );
      case 'provider_assigned':
        return StatusInfo(
          label: 'Provider Assigned',
          color: Colors.green,
          icon: Icons.person_pin_circle_rounded,
        );
      case 'payment_pending':
        return StatusInfo(
          label: 'Payment Pending',
          color: Colors.red,
          icon: Icons.payment_rounded,
        );
      case 'confirmed':
        return StatusInfo(
          label: 'Confirmed',
          color: Colors.teal,
          icon: Icons.check_circle_rounded,
        );
      case 'on_the_way':
        return StatusInfo(
          label: 'On The Way',
          color: Colors.purple,
          icon: Icons.directions_car_rounded,
        );
      case 'completed':
        return StatusInfo(
          label: 'Completed',
          color: Colors.greenAccent,
          icon: Icons.task_alt_rounded,
        );
      case 'cancelled':
        return StatusInfo(
          label: 'Cancelled',
          color: Colors.redAccent,
          icon: Icons.cancel_rounded,
        );
      default:
        return StatusInfo(
          label: status,
          color: Colors.grey,
          icon: Icons.info_rounded,
        );
    }
  }

  String _formatDate(DateTime date) {
    final months = [
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showBookingPreviewSheet(
    Map<String, dynamic> booking,
    String bookingId,
  ) {
    final serviceName =
        booking['serviceCategory'] ?? booking['serviceName'] ?? 'Service';
    final status = booking['status'] ?? 'pending';
    final budget =
        (booking['budget'] ?? booking['price'] as num?)?.toDouble() ?? 0;
    final scheduledTime = booking['scheduledTime'] ?? booking['time'] ?? '';
    final problem = booking['serviceDescription'] ?? booking['problem'] ?? '';
    final customerName = booking['customerName'] ?? 'Valued Customer';
    final customerPhone = booking['customerPhone'] ?? 'N/A';
    final dateStr = booking['bookingDate'] ?? booking['date'] ?? '';
    final partnerId = (booking['partnerId'] ?? '').toString();
    final embeddedProvider =
        booking['providerDetails'] as Map<String, dynamic>?;
    final providerData = partnerId.isNotEmpty
        ? _providerCache[partnerId]
        : null;
    final effectiveProvider = providerData ?? embeddedProvider;
    final providerName =
        effectiveProvider?['name'] ?? booking['providerName'] ?? serviceName;
    final providerQualification = (effectiveProvider?['qualification'] ?? '')
        .toString();
    final providerSpecialty =
        (effectiveProvider?['specialization'] ??
                effectiveProvider?['specialty'] ??
                '')
            .toString();
    final providerCategory = (effectiveProvider?['category'] ?? '').toString();
    final providerExperience =
        (effectiveProvider?['experience'] ??
                effectiveProvider?['yearsOfExperience'] ??
                '')
            .toString();
    final providerRating = (effectiveProvider?['rating'] ?? '').toString();
    final providerAddress =
        (effectiveProvider?['shopAddress'] ??
                effectiveProvider?['address'] ??
                effectiveProvider?['business_address'] ??
                '')
            .toString();
    final providerPhone = (effectiveProvider?['phone'] ?? '').toString();
    final providerImage =
        (effectiveProvider?['profileImage'] ??
                effectiveProvider?['image'] ??
                '')
            .toString();
    final statusInfo = _getStatusInfo(status);

    final scheduledDate = _parseDate(booking);
    final formattedDate = scheduledDate != null
        ? _formatDate(scheduledDate)
        : dateStr.toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        bool isSharing = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF111016),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              if (providerImage.isNotEmpty)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: CachedNetworkImageProvider(
                                        providerImage,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFF7A1A,
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.business_rounded,
                                    color: Color(0xFFFF7A1A),
                                    size: 24,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      providerName.toString(),
                                      style: GoogleFonts.orbitron(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      serviceName.toString(),
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFFF7A1A),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusInfo.color.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusInfo.label,
                                  style: GoogleFonts.poppins(
                                    color: statusInfo.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 12),
                          Text(
                            'BOOKING DETAILS',
                            style: GoogleFonts.orbitron(
                              color: const Color(0xFFFF7A1A),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _previewRow(
                            Icons.calendar_today_rounded,
                            'Date',
                            formattedDate,
                          ),
                          const SizedBox(height: 10),
                          _previewRow(
                            Icons.access_time_rounded,
                            'Time',
                            scheduledTime.toString(),
                          ),
                          const SizedBox(height: 10),
                          _previewRow(
                            Icons.currency_rupee_rounded,
                            'Budget',
                            'Rs. ${budget.toStringAsFixed(0)}',
                          ),
                          const SizedBox(height: 10),
                          _previewRow(
                            Icons.person_rounded,
                            'Customer',
                            customerName.toString(),
                          ),
                          if (customerPhone != 'N/A') ...[
                            const SizedBox(height: 10),
                            _previewRow(
                              Icons.phone_rounded,
                              'Phone',
                              customerPhone.toString(),
                            ),
                          ],
                          if (problem.toString().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _previewRow(
                              Icons.description_outlined,
                              'Details',
                              problem.toString(),
                            ),
                          ],
                          // Provider details if available
                          if (providerQualification.isNotEmpty ||
                              providerSpecialty.isNotEmpty ||
                              providerCategory.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 12),
                            Text(
                              'SERVICE PROVIDER',
                              style: GoogleFonts.orbitron(
                                color: const Color(0xFFFF7A1A),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (providerCategory.isNotEmpty)
                              _previewRow(
                                Icons.category_rounded,
                                'Category',
                                providerCategory,
                              ),
                            if (providerSpecialty.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _previewRow(
                                Icons.star_rounded,
                                'Specialty',
                                providerSpecialty,
                              ),
                            ],
                            if (providerQualification.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _previewRow(
                                Icons.school_rounded,
                                'Qualification',
                                providerQualification,
                              ),
                            ],
                            if (providerExperience.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _previewRow(
                                Icons.work_rounded,
                                'Experience',
                                providerExperience,
                              ),
                            ],
                            if (providerRating.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _previewRow(
                                Icons.thumb_up_rounded,
                                'Rating',
                                providerRating,
                              ),
                            ],
                            if (providerAddress.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _previewRow(
                                Icons.location_on_rounded,
                                'Address',
                                providerAddress,
                              ),
                            ],
                            if (providerPhone.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _previewRow(
                                Icons.phone_rounded,
                                'Phone',
                                providerPhone,
                              ),
                            ],
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: isSharing
                                  ? null
                                  : () {
                                      setSheetState(() => isSharing = true);
                                      Navigator.pop(ctx);
                                      _downloadBookingPdf(booking, bookingId);
                                    },
                              icon: isSharing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.picture_as_pdf_rounded),
                              label: Text(
                                isSharing ? 'GENERATING PDF...' : 'SHARE PDF',
                                style: GoogleFonts.orbitron(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7A1A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _previewRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFFF7A1A), size: 16),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Generate and share/download booking PDF
  void _downloadBookingPdf(
    Map<String, dynamic> booking,
    String bookingId,
  ) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF7A1A)),
      ),
    );

    try {
      final pdf = pw.Document();

      pw.MemoryImage? logoImage;
      try {
        final ByteData logoData = await rootBundle.load('assets/logo.png');
        final Uint8List logoBytes = logoData.buffer.asUint8List();
        logoImage = pw.MemoryImage(logoBytes);
      } catch (e) {
        Log.e('MyBookingsScreen', 'Error loading logo: $e');
      }

      // Extract booking fields
      final serviceName =
          (booking['serviceCategory'] ?? booking['serviceName'] ?? 'Service')
              .toString();
      final customerName = (booking['customerName'] ?? 'Valued Customer')
          .toString();
      final customerPhone = (booking['customerPhone'] ?? 'N/A').toString();
      final providerName = (booking['providerName'] ?? serviceName).toString();
      final budget =
          (booking['budget'] ?? booking['price'] as num?)?.toDouble() ?? 0;
      final scheduledTime = (booking['scheduledTime'] ?? booking['time'] ?? '')
          .toString();
      final problem =
          (booking['serviceDescription'] ?? booking['problem'] ?? '')
              .toString();
      final dateStr = booking['bookingDate'] ?? booking['date'] ?? '';

      // New pricing breakdown fields
      final double basePrice =
          (booking['basePrice'] ?? (budget > 30 ? budget - 30 : budget))
              .toDouble();
      final double markup = (booking['markup'] ?? 10.0).toDouble();
      final double platformFee = (booking['platformFee'] ?? 20.0).toDouble();
      final double gst = (booking['gst'] ?? (markup + platformFee) * 0.18)
          .toDouble();
      final double totalAmount = (booking['totalPrice'] ?? budget).toDouble();

      // Colors
      const bgColor = PdfColor.fromInt(0xFF0A0A0F);
      const cardBg = PdfColor.fromInt(0xFF14141E);
      const orange = PdfColors.orange;
      const white = PdfColors.white;
      const grey = PdfColor.fromInt(0xFFB0B0B0);
      const divider = PdfColor.fromInt(0xFF2A2A3A);

      pdf.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(28),
            buildBackground: (pw.Context ctx) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Container(color: bgColor),
            ),
          ),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoImage != null)
                          pw.Image(logoImage, width: 60, height: 60)
                        else
                          pw.Text(
                            'MULTIVERSECITY',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: orange,
                            ),
                          ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'Booking Receipt',
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: grey,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: const pw.BoxDecoration(
                            color: orange,
                            borderRadius: pw.BorderRadius.all(
                              pw.Radius.circular(6),
                            ),
                          ),
                          child: pw.Text(
                            'CONFIRMED',
                            style: pw.TextStyle(
                              color: white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'ID: $bookingId',
                          style: const pw.TextStyle(fontSize: 9, color: grey),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Divider(thickness: 1, color: divider),
                pw.SizedBox(height: 20),

                // Provider
                pw.Text(
                  'SERVICE PROVIDER',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: orange,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: const pw.BoxDecoration(
                    color: cardBg,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        providerName,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        serviceName,
                        style: const pw.TextStyle(fontSize: 11, color: orange),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Customer + Schedule
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'CUSTOMER',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: orange,
                              letterSpacing: 1.2,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            customerName,
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Phone: $customerPhone',
                            style: const pw.TextStyle(fontSize: 10, color: grey),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SCHEDULE',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: orange,
                              letterSpacing: 1.2,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Date: $dateStr',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Time: $scheduledTime',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                if (problem.isNotEmpty) ...[
                  pw.Text(
                    'DESCRIPTION',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: orange,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    problem,
                    style: const pw.TextStyle(fontSize: 10, color: grey),
                  ),
                  pw.SizedBox(height: 20),
                ],

                // Price Breakdown
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(14),
                  decoration: const pw.BoxDecoration(
                    color: cardBg,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PRICE BREAKDOWN',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: orange,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Booking Price',
                            style: const pw.TextStyle(fontSize: 11, color: grey),
                          ),
                          pw.Text(
                            'Rs. ${(basePrice + markup).toStringAsFixed(0)}',
                            style: const pw.TextStyle(fontSize: 11, color: white),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Platform Fee',
                            style: const pw.TextStyle(fontSize: 11, color: grey),
                          ),
                          pw.Text(
                            'Rs. ${platformFee.toStringAsFixed(0)}',
                            style: const pw.TextStyle(fontSize: 11, color: white),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'GST (18%)',
                            style: const pw.TextStyle(fontSize: 11, color: grey),
                          ),
                          pw.Text(
                            'Rs. ${gst.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 11, color: white),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Divider(thickness: 0.5, color: divider),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL PAYABLE',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: orange,
                            ),
                          ),
                          pw.Text(
                            'Rs. ${totalAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Footer
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: divider, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    'This is an Automatically Generated PDF',
                    style: const pw.TextStyle(fontSize: 9, color: grey),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Center(
                  child: pw.Text(
                    '${AppContactInfo.supportEmail} | multiversecity.com',
                    style: const pw.TextStyle(fontSize: 8, color: grey),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final pdfFile = File('${dir.path}/Booking_$bookingId.pdf');
      await pdfFile.writeAsBytes(pdfBytes);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
      }

      // Share the PDF
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfFile.path)],
          text: 'Booking Receipt - $bookingId',
        ),
      );
    } catch (e) {
      Log.e('MyBookingsScreen', 'PDF generation error: $e');
      if (mounted) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class StatusInfo {
  final String label;
  final Color color;
  final IconData icon;

  StatusInfo({required this.label, required this.color, required this.icon});
}
