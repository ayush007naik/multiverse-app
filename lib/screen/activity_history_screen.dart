import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/premium_ui_widgets.dart';
import 'order_details_screen.dart';

class ActivityHistoryScreen extends StatefulWidget {
  final int initialTabIndex;
  const ActivityHistoryScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080B),
      body: Stack(
        children: [
          _buildAmbientGlow(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildShoppingHistory(),
                      _buildMovieHistory(),
                      _buildServiceHistory(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlow() {
    return Positioned(
      top: -100,
      right: -50,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFF6A3D).withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'ACTIVITY',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6A3D), Color(0xFFB066FF)],
          ),
        ),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: GoogleFonts.orbitron(
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
        tabs: const [
          Tab(text: 'SHOPPING'),
          Tab(text: 'MOVIES'),
          Tab(text: 'APPOINTMENTS'),
        ],
      ),
    );
  }

  Widget _buildShoppingHistory() {
    final user = _auth.currentUser;
    if (user == null) return _buildEmptyState('No login detected');

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .limit(50)
          .snapshots(), // Removed orderBy to avoid index requirement
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6A3D)),
          );
        }
        if (snapshot.hasError) {
          return _buildEmptyState('Error loading orders');
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState('No shopping history');

        // Sort client-side by createdAt
        final sortedDocs = List.from(docs);
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Descending order
        });

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final data = sortedDocs[index].data() as Map<String, dynamic>;
            return _buildOrderCard(data, sortedDocs[index].id);
          },
        );
      },
    );
  }

  Widget _buildMovieHistory() {
    final user = _auth.currentUser;
    if (user == null) return _buildEmptyState('No login detected');

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('movie_bookings')
          .where('userId', isEqualTo: user.uid)
          .limit(50)
          .snapshots(), // Removed orderBy to avoid index requirement
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6A3D)),
          );
        }
        if (snapshot.hasError) {
          return _buildEmptyState('Error loading movie bookings');
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState('No movie bookings');

        // Sort client-side by bookingTime
        final sortedDocs = List.from(docs);
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['bookingTime'] as Timestamp?;
          final bTime = bData['bookingTime'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Descending order
        });

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final data = sortedDocs[index].data() as Map<String, dynamic>;
            return _buildMovieCard(data);
          },
        );
      },
    );
  }

  Widget _buildServiceHistory() {
    final user = _auth.currentUser;
    if (user == null) return _buildEmptyState('No login detected');

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('service_requests')
          .where('userId', isEqualTo: user.uid)
          .limit(50)
          .snapshots(), // Removed orderBy to avoid index requirement
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6A3D)),
          );
        }
        if (snapshot.hasError) {
          return _buildEmptyState('Error loading service requests');
        }
        final docs = snapshot.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('appointments')
              .where('userId', isEqualTo: user.uid)
              .limit(50)
              .snapshots(), // Removed orderBy
          builder: (context, apptSnapshot) {
            if (apptSnapshot.hasError) {
              return _buildEmptyState('Error loading appointments');
            }
            final appts = apptSnapshot.data?.docs ?? [];
            final allServices = [...docs, ...appts];

            // Sort client-side by createdAt descending
            allServices.sort((a, b) {
              final aTime =
                  (a.data())['createdAt'] as Timestamp?;
              final bTime =
                  (b.data())['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

            if (allServices.isEmpty) {
              return _buildEmptyState('No service history');
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: allServices.length,
              itemBuilder: (context, index) {
                final doc = allServices[index];
                final data = doc.data();
                final isAppointment = doc.reference.parent.id == 'appointments';
                return _buildServiceCard(data, isAppointment);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_rounded, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> data, String id) {
    final status = (data['status'] as String? ?? 'pending').toLowerCase();
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final shopName = data['shopName'] as String? ?? 'Multiverse Shop';
    final rawItems = data['items'];
    final items = rawItems is List ? rawItems.length : 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: id)),
        );
      },
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        backdropBlur: false,
        child: Row(
          children: [
            _buildIconBox(Icons.shopping_bag_outlined, const Color(0xFFFF6A3D)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$items items • ₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(data['createdAt']),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            _buildStatusTag(status),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieCard(Map<String, dynamic> data) {
    final title = data['movieTitle'] as String? ?? 'Movie';
    final theatre = data['theatreName'] as String? ?? 'Cinema';
    final seats = (data['seats'] as List?)?.join(', ') ?? '';
    final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      backdropBlur: false,
      child: Row(
        children: [
          _buildIconBox(Icons.movie_filter_rounded, const Color(0xFFB066FF)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$theatre • $seats',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${total.toStringAsFixed(0)} • ${_formatDate(data['bookingTime'])}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          _buildStatusTag('confirmed'),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> data, bool isAppointment) {
    final title = isAppointment
        ? (data['doctorName'] ?? 'Doctor Consultation')
        : (data['serviceType'] ?? 'Service Request');
    final status = (data['status'] as String? ?? 'pending').toLowerCase();

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      backdropBlur: false,
      child: Row(
        children: [
          _buildIconBox(
            isAppointment
                ? Icons.medical_services_outlined
                : Icons.build_circle_outlined,
            const Color(0xFF43C6FF),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAppointment
                      ? '${data['date']} • ${data['time']}'
                      : 'Multiverse Professional',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(data['createdAt']),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          _buildStatusTag(status),
        ],
      ),
    );
  }

  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildStatusTag(String status) {
    Color color;
    switch (status) {
      case 'delivered':
      case 'confirmed':
      case 'completed':
        color = const Color(0xFF4ADE80);
      case 'cancelled':
        color = const Color(0xFFF87171);
      default:
        color = const Color(0xFFFFC94D);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is! Timestamp) return 'Recently';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}
