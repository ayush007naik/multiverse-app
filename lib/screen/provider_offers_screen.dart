import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:db_compat/db_compat.dart';
import '../../widgets/premium_ui_widgets.dart';
import '../../services/service_provider_service.dart';
import 'counter_offer_screen.dart';

class ProviderOffersScreen extends StatefulWidget {
  final String bookingId;

  const ProviderOffersScreen({super.key, required this.bookingId});

  @override
  State<ProviderOffersScreen> createState() => _ProviderOffersScreenState();
}

class _ProviderOffersScreenState extends State<ProviderOffersScreen> {
  final ServiceProviderService _serviceProviderService =
      ServiceProviderService();
  bool _showBoostSuggestion = false;
  Timer? _boostTimer;

  @override
  void initState() {
    super.initState();
    _validateBookingId();

    // Show boost suggestion after 60 seconds if no offers
    _boostTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) {
        setState(() {
          _showBoostSuggestion = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _boostTimer?.cancel();
    super.dispose();
  }

  void _validateBookingId() {
    if (widget.bookingId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking request not found'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bookingId.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'RECEIVED OFFERS',
          style: GoogleFonts.orbitron(
            fontSize: 16,
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFF7A1A)),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: _buildOffersList(),
    );
  }

  Widget _buildOffersList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _serviceProviderService.getBookingOffers(widget.bookingId),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoading();
        }

        // Error state - ONLY for real errors
        if (snapshot.hasError) {
          return _buildErrorState(snapshot);
        }

        // Empty state - NO OFFERS YET (not an error!)
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        // Has offers - show them
        final offers = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index];
            return FadeSlideAnimation(
              delay: Duration(milliseconds: 100 * index),
              child: _buildOfferCard(offer),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          height: 250,
          margin: const EdgeInsets.only(bottom: 16),
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

  Widget _buildErrorState(AsyncSnapshot<List<Map<String, dynamic>>>? snapshot) {
    final error = snapshot?.error?.toString() ?? '';
    String errorMessage = 'An unexpected error occurred';
    IconData errorIcon = Icons.cloud_off_rounded;

    // Determine specific error message (hide Firebase debug text)
    if (error.contains('permission') || error.contains('unauthorized')) {
      errorMessage = 'Database permission error. Please contact support.';
      errorIcon = Icons.security_rounded;
    } else if (error.contains('network') || error.contains('unavailable')) {
      errorMessage = 'No internet connection. Please check your network.';
      errorIcon = Icons.wifi_off_rounded;
    } else if (error.contains('not-found') || error.contains('missing')) {
      errorMessage = 'Booking request not found.';
      errorIcon = Icons.search_off_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(errorIcon, color: Colors.red.withValues(alpha: 0.8), size: 80),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'RETRY',
                style: GoogleFonts.orbitron(fontWeight: FontWeight.w700),
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

  /// EMPTY STATE UI - Shown when no offers yet (NOT an error)
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Searching animation icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.2),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Icon(
                    Icons.explore_rounded,
                    size: 100,
                    color: const Color(0xFFFF7A1A).withValues(alpha: 0.3),
                  ),
                );
              },
              onEnd: () {
                if (mounted) {
                  setState(() {}); // Trigger animation repeat
                }
              },
            ),
            const SizedBox(height: 32),
            Text(
              'No providers available yet',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'We\'re still searching nearby professionals',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Refresh button
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    'REFRESH',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A1A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Edit booking button
                OutlinedButton.icon(
                  onPressed: () {
                    // Navigate back to edit booking
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(
                    'EDIT BOOKING',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF7A1A),
                    side: const BorderSide(color: Color(0xFFFF7A1A), width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            // Boost visibility suggestion (shown after 60 seconds)
            if (_showBoostSuggestion) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF7A1A).withValues(alpha: 0.15),
                      const Color(0xFFFF7A1A).withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFF7A1A).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.rocket_launch_rounded,
                      color: Color(0xFFFF7A1A),
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Boost Visibility?',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Increase your budget to attract more providers',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to edit booking with budget suggestion
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Edit your booking to increase budget',
                            ),
                            backgroundColor: Color(0xFFFF7A1A),
                          ),
                        );
                      },
                      icon: const Icon(Icons.trending_up_rounded, size: 18),
                      label: Text(
                        'INCREASE BUDGET',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A1A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Providers in your area will be notified. Average response time: 5-10 minutes.',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
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

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final providerId = offer['providerId'] as String;
    final offeredPrice = (offer['offeredPrice'] as num).toDouble();
    final estimatedTime = offer['estimatedTime'] as String;
    final message = offer['message'] as String? ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .snapshots(),
      builder: (context, providerSnapshot) {
        if (providerSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 200);
        }

        if (!providerSnapshot.hasData || !providerSnapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final providerData =
            providerSnapshot.data!.data() as Map<String, dynamic>;
        final providerName = providerData['name'] as String? ?? 'Provider';
        final providerRating = (providerData['rating'] as num? ?? 0.0)
            .toDouble();
        final providerReviews = providerData['totalReviews'] as int? ?? 0;
        final profileImage = providerData['profileImage'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7A1A).withValues(alpha: 0.05),
                blurRadius: 20,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF7A1A).withValues(alpha: 0.3),
                        ),
                        image: profileImage != null
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(profileImage),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: profileImage == null
                          ? Center(
                              child: Text(
                                providerName.isNotEmpty ? providerName[0] : 'P',
                                style: GoogleFonts.orbitron(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            providerName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${providerRating.toStringAsFixed(1)} ($providerReviews reviews)',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'NEW OFFER',
                        style: GoogleFonts.orbitron(
                          color: Colors.greenAccent,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A1A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offered Price',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${offeredPrice.toStringAsFixed(0)}',
                            style: GoogleFonts.orbitron(
                              color: const Color(0xFFFF7A1A),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              estimatedTime,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      message,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Offer accepted!')),
                          );
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          'ACCEPT',
                          style: GoogleFonts.orbitron(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CounterOfferScreen(
                                providerName: providerName,
                                providerPrice: offeredPrice.toInt(),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_rounded),
                        label: Text(
                          'COUNTER',
                          style: GoogleFonts.orbitron(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A1A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
      },
    );
  }
}

class PulsingAnimation extends StatefulWidget {
  final Widget child;
  const PulsingAnimation({super.key, required this.child});

  @override
  State<PulsingAnimation> createState() => _PulsingAnimationState();
}

class _PulsingAnimationState extends State<PulsingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
