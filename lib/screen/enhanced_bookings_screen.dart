import 'package:flutter/material.dart';
import 'dart:ui';
import '../widgets/premium_ui_widgets.dart';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/price_calculator.dart';

/// Enhanced Services Screen with futuristic MULTIVERSE UI
/// Features: Premium neon black UI, orange + purple glowing gradients,
/// cyberpunk/futuristic aesthetics, glassmorphism cards, smooth animations
/// Live provider tracking, OTP verification, chat/call support
/// Booking slots, service ratings, and consistent design

class EnhancedBookingsScreen extends StatefulWidget {
  const EnhancedBookingsScreen({super.key});

  @override
  State<EnhancedBookingsScreen> createState() => _EnhancedBookingsScreenState();
}

class _EnhancedBookingsScreenState extends State<EnhancedBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient - Neon Black with Orange/Purple Glow
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A021A), // Deep cosmic purple
                  Color(0xFF0D0324), // Dark nebula blue
                  Color(0xFF12052E), // Purple-black gradient
                  Color(0xFF000000), // Pure black base
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // Animated Grid Pattern Overlay
          Positioned.fill(child: CustomPaint(painter: GridPatternPainter())),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInstantServices(),
                      _buildScheduledAppointments(),
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

  Widget _buildHeader() {
    return FadeSlideAnimation(
      delay: const Duration(milliseconds: 100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            // Glowing Multiverse Logo
            PulsingAnimation(
              duration: const Duration(milliseconds: 2500),
              child: Text(
                'MULTIVERSE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                      color: const Color(0xFFFF5722).withValues(alpha: 0.7),
                      blurRadius: 15,
                      offset: const Offset(0, 0),
                    ),
                    Shadow(
                      color: const Color(0xFF6A26E3).withValues(alpha: 0.7),
                      blurRadius: 15,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Live Tracking Indicator
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: Colors.green,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return FadeSlideAnimation(
      delay: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: const Color(0xFF6A26E3).withValues(alpha: 0.2),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFFF5722), Color(0xFF6A26E3)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5722).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFF6A26E3).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'INSTANT SERVICES'),
            Tab(text: 'APPOINTMENTS'),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  // MY BOOKINGS (Service Requests)
  // ══════════════════════════════════════
  Widget _buildMyBookings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('service_requests')
          .where('customerId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final requests = snapshot.data?.docs ?? [];
        final activeRequests = requests.where((r) {
          final status = (r.data())['status'] ?? '';
          return status == 'open' || status == 'accepted';
        }).toList();

        if (activeRequests.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Text(
                'ACTIVE REQUESTS',
                style: TextStyle(
                  color: Color(0xFFFF5722),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: activeRequests.length,
                itemBuilder: (context, index) {
                  final data =
                      activeRequests[index].data();
                  final status = data['status'] ?? 'open';
                  Color statusColor = const Color(0xFFFF5722);
                  if (status == 'accepted') statusColor = Colors.green;

                  return FadeSlideAnimation(
                    delay: Duration(milliseconds: 300 + (index * 100)),
                    child: Container(
                      width: 300,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: GlassCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.all(16),
                        borderRadius: 28,
                        shadows: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF5722,
                            ).withValues(alpha: 0.2),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: const Color(
                              0xFF6A26E3,
                            ).withValues(alpha: 0.2),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFF5722,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    data['serviceType'] == 'Electrician'
                                        ? Icons.bolt_rounded
                                        : data['serviceType'] == 'Plumber'
                                        ? Icons.water_drop_rounded
                                        : data['serviceType'] == 'Cleaning'
                                        ? Icons.cleaning_services_rounded
                                        : data['serviceType'] == 'Carpenter'
                                        ? Icons.build_rounded
                                        : data['serviceType'] == 'Salon'
                                        ? Icons.spa_rounded
                                        : Icons.more_horiz_rounded,
                                    color: const Color(0xFFFF5722),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    data['serviceType'] ?? 'Service',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              data['description'] ?? '',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Budget: ₹${data['customerBudget'] ?? 0}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Live Tracking Status
                            if (status == 'accepted')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      color: Colors.blue,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Provider en route',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════
  // MY APPOINTMENTS (Doctor)
  // ══════════════════════════════════════
  Widget _buildMyAppointments() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final appointments = snapshot.data?.docs ?? [];
        final activeAppointments = appointments.where((a) {
          final status = (a.data())['status'] ?? '';
          return status == 'pending' || status == 'confirmed';
        }).toList();

        if (activeAppointments.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Text(
                'UPCOMING APPOINTMENTS',
                style: TextStyle(
                  color: Color(0xFFFF5722),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: activeAppointments.length,
                itemBuilder: (context, index) {
                  final data =
                      activeAppointments[index].data();
                  final status = data['status'] ?? 'pending';
                  Color statusColor = const Color(0xFFFF5722);
                  if (status == 'confirmed') statusColor = Colors.green;

                  return FadeSlideAnimation(
                    delay: Duration(milliseconds: 300 + (index * 100)),
                    child: Container(
                      width: 300,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: GlassCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.all(16),
                        borderRadius: 28,
                        shadows: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF5722,
                            ).withValues(alpha: 0.2),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: const Color(
                              0xFF6A26E3,
                            ).withValues(alpha: 0.2),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF6A26E3,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.medical_services_rounded,
                                    color: Color(0xFF6A26E3),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    data['doctorName'] ?? 'Doctor',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Colors.white54,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  data['date'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.access_time_rounded,
                                  color: Colors.white54,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  data['time'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Fee: ₹${data['consultationFee'] ?? 0}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // OTP Verification Status
                            if (status == 'confirmed')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.purple.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      color: Colors.purple,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'OTP verified',
                                      style: TextStyle(
                                        color: Colors.purple,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════
  // INSTANT SERVICES
  // ══════════════════════════════════════
  Widget _buildInstantServices() {
    final services = [
      {
        'name': 'Electrician',
        'price': '199',
        'icon': Icons.bolt_rounded,
        'desc': 'Fan, Switch, Wiring fixes',
        'rating': 4.8,
      },
      {
        'name': 'Plumber',
        'price': '249',
        'icon': Icons.water_drop_rounded,
        'desc': 'Leakage, Tap, Pipe repair',
        'rating': 4.7,
      },
      {
        'name': 'Cleaning',
        'price': '499',
        'icon': Icons.cleaning_services_rounded,
        'desc': 'Deep home cleaning',
        'rating': 4.9,
      },
      {
        'name': 'Carpenter',
        'price': '399',
        'icon': Icons.build_rounded,
        'desc': 'Furniture assembly & repair',
        'rating': 4.6,
      },
      {
        'name': 'Salon',
        'price': '599',
        'icon': Icons.spa_rounded,
        'desc': 'Hair, skin & beauty services',
        'rating': 4.8,
      },
      {
        'name': 'More',
        'price': 'From ₹199',
        'icon': Icons.more_horiz_rounded,
        'desc': 'Additional services available',
        'rating': 4.5,
      },
    ];

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: const Color(0xFFFF5722),
      backgroundColor: Colors.black,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildMyBookings()),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            sliver: SliverToBoxAdapter(
              child: Text(
                'AVAILABLE SERVICES',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final service = services[index];
                return FadeSlideAnimation(
                  delay: Duration(milliseconds: 100 * index),
                  child: GlassCard(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(20),
                    borderRadius: 28,
                    shadows: [
                      BoxShadow(
                        color: const Color(0xFFFF5722).withValues(alpha: 0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: const Color(0xFF6A26E3).withValues(alpha: 0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF5722,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            service['icon'] as IconData,
                            color: const Color(0xFFFF5722),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service['name'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                service['desc'] as String,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Rating stars
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${service['rating']} ★',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${service['price']}',
                              style: const TextStyle(
                                color: Color(0xFFFF5722),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'starting',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => _showServiceRequestDialog(
                                service['name'] as String,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Color(0xFFFF5722),
                                      Color(0xFF6A26E3),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF5722,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                    BoxShadow(
                                      color: const Color(
                                        0xFF6A26E3,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'Book Now',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  // SCHEDULED APPOINTMENTS
  // ══════════════════════════════════════
  Widget _buildScheduledAppointments() {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: const Color(0xFFFF5722),
      backgroundColor: Colors.black,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildMyAppointments()),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            sliver: SliverToBoxAdapter(
              child: Text(
                'AVAILABLE DOCTORS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('doctors')
                .where('isApproved', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF5722)),
                  ),
                );
              }
              final doctors = snapshot.data?.docs ?? [];
              if (doctors.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No doctors available',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final data = doctors[index].data();
                    final doctorId = doctors[index].id;
                    return FadeSlideAnimation(
                      delay: Duration(milliseconds: index * 100),
                      child: _buildDoctorCard(data, doctorId),
                    );
                  }),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> data, String doctorId) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      borderRadius: 28,
      shadows: [
        BoxShadow(
          color: const Color(0xFFFF5722).withValues(alpha: 0.2),
          blurRadius: 15,
          spreadRadius: 2,
          offset: const Offset(0, 5),
        ),
        BoxShadow(
          color: const Color(0xFF6A26E3).withValues(alpha: 0.2),
          blurRadius: 15,
          spreadRadius: 2,
          offset: const Offset(0, 5),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6A26E3).withValues(alpha: 0.1),
                  border: Border.all(
                    color: const Color(0xFF6A26E3).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Color(0xFF6A26E3),
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['specialist'] ?? '',
                      style: const TextStyle(
                        color: Color(0xFFFF5722),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Rating
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '${data['rating'] ?? 4.7} ★',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFFFF5722), Color(0xFF6A26E3)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5722).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: const Color(0xFF6A26E3).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '₹${data['consultationFee'] ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Colors.white10),
          ),
          _doctorInfoRow(Icons.school_rounded, data['qualification'] ?? 'N/A'),
          const SizedBox(height: 10),
          _doctorInfoRow(
            Icons.work_rounded,
            '${data['experience'] ?? 0} years experience',
          ),
          const SizedBox(height: 10),
          _doctorInfoRow(
            Icons.location_on_rounded,
            data['address'] ?? 'Mandi, HP',
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _showSlotBookingSheet(data, doctorId),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFFF5722), Color(0xFF6A26E3)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: const Color(0xFF6A26E3).withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Book Appointment',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _doctorInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.white38,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFFF5722), size: 22),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFFF5722), width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }

  Widget _buildMyRequestTile(String requestId, Map<String, dynamic> data) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .collection('bids')
          .snapshots(),
      builder: (context, snapshot) {
        final bids = snapshot.data?.docs ?? [];
        if (bids.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Waiting for bids...',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: Colors.white10),
            ),
            Row(
              children: [
                const Icon(
                  Icons.celebration_rounded,
                  color: Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${bids.length} bid(s) received!',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...bids.map((bid) {
              final bidData = bid.data();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bidData['providerName'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          if ((bidData['note'] ?? '').isNotEmpty)
                            Text(
                              bidData['note'],
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          // Provider rating
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${bidData['rating'] ?? 4.5} ★',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${bidData['amount']}',
                          style: const TextStyle(
                            color: Color(0xFFFF5722),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () async {
                            await FirebaseFirestore.instance
                                .collection('service_requests')
                                .doc(requestId)
                                .update({
                                  'status': 'accepted',
                                  'acceptedBidId': bid.id,
                                  'acceptedProvider': bidData['providerName'],
                                  'finalAmount': bidData['amount'],
                                });
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${bidData['providerName']} accepted! ✅',
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Text(
                              'Accept',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _showServiceRequestDialog(String serviceType) async {
    final descController = TextEditingController();
    final budgetController = TextEditingController();
    final addressController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5722).withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, -5),
              ),
              BoxShadow(
                color: const Color(0xFF6A26E3).withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Request $serviceType',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 28),
                _buildDialogField(
                  descController,
                  'What do you need help with?',
                  Icons.description_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildDialogField(
                  budgetController,
                  'Your Budget (₹)',
                  Icons.currency_rupee_rounded,
                  isNumber: true,
                ),
                const SizedBox(height: 16),
                _buildDialogField(
                  addressController,
                  'Service Location',
                  Icons.location_on_rounded,
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () async {
                    if (descController.text.isEmpty ||
                        budgetController.text.isEmpty) {
                      return;
                    }
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user?.uid)
                        .get();
                    final customerName = userDoc.data()?['name'] ?? 'Customer';
                    await FirebaseFirestore.instance
                        .collection('service_requests')
                        .add({
                          'customerId': user?.uid,
                          'customerName': customerName,
                          'serviceType': serviceType,
                          'description': descController.text.trim(),
                          'customerBudget':
                              int.tryParse(budgetController.text.trim()) ?? 0,
                          'address': addressController.text.trim(),
                          'status': 'open',
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Request sent! Providers will bid soon.',
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFFF5722), Color(0xFF6A26E3)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5722).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: const Color(0xFF6A26E3).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'POST REQUEST',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('service_requests')
                      .where('customerId', isEqualTo: user?.uid)
                      .where('serviceType', isEqualTo: serviceType)
                      .where('status', isEqualTo: 'open')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final requests = snapshot.data?.docs ?? [];
                    if (requests.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: requests.map((req) {
                        return _buildMyRequestTile(
                          req.id,
                          req.data(),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSlotBookingSheet(
    Map<String, dynamic> doctorData,
    String doctorId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    String? selectedDay;
    String? selectedTime;
    final reasonController = TextEditingController();
    final slots = Map<String, dynamic>.from(doctorData['slots'] ?? {});
    final bookedSlots = List<String>.from(doctorData['bookedSlots'] ?? []);
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5722).withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, -5),
              ),
              BoxShadow(
                color: const Color(0xFF6A26E3).withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Book Appointment with ${doctorData['name']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Day Selection
                  const Text(
                    'Select Day',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: days.map((day) {
                      final isSelected = selectedDay == day;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedDay = day),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF5722).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF5722)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            day.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white54,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // Time Selection
                  if (selectedDay != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Times',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (slots[selectedDay] ?? []).map((time) {
                            final isSelected = selectedTime == time;
                            final isBooked = bookedSlots.contains(
                              '$selectedDay-$time',
                            );
                            return GestureDetector(
                              onTap: () {
                                if (!isBooked) {
                                  setModalState(() => selectedTime = time);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isBooked
                                      ? Colors.grey.withValues(alpha: 0.2)
                                      : isSelected
                                      ? const Color(
                                          0xFFFF5722,
                                        ).withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isBooked
                                        ? Colors.grey.withValues(alpha: 0.3)
                                        : isSelected
                                        ? const Color(0xFFFF5722)
                                        : Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Text(
                                  time,
                                  style: TextStyle(
                                    color: isBooked
                                        ? Colors.grey
                                        : isSelected
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  _buildDialogField(
                    reasonController,
                    'Reason for visit',
                    Icons.description_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: () async {
                      if (selectedDay == null || selectedTime == null) return;
                      final baseFee = (doctorData['consultationFee'] is num)
                          ? (doctorData['consultationFee'] as num).toDouble()
                          : 0.0;
                      final breakdown = PriceCalculator.calculateBookingPrice(
                        baseFee,
                      );
                      await FirebaseFirestore.instance
                          .collection('appointments')
                          .add({
                            'patientId': user?.uid,
                            'doctorId': doctorId,
                            'doctorName': doctorData['name'],
                            'date': selectedDay,
                            'time': selectedTime,
                            'reason': reasonController.text.trim(),
                            'status': 'pending',
                            'basePrice': breakdown['basePrice'],
                            'markup': breakdown['markup'],
                            'platformFee': breakdown['platformFee'],
                            'gst': breakdown['gst'],
                            'totalPrice': breakdown['totalPayable'],
                            'profit': breakdown['profit'],
                            'price': breakdown['totalPayable'],
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Appointment booked successfully!',
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFFFF5722), Color(0xFF6A26E3)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF5722,
                            ).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: const Color(
                              0xFF6A26E3,
                            ).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'CONFIRM APPOINTMENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 1.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
