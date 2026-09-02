import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/provider_model.dart';
import '../services/provider_service.dart';
import '../core/logging_service.dart';

/// Provider Dashboard Screen
/// Real-time dashboard for service providers to manage bookings, offers, and earnings
class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  final ProviderService _providerService = ProviderService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isAvailable = true;
  String _selectedTab =
      'requests'; // 'requests', 'active', 'completed', 'earnings'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'PROVIDER DASHBOARD',
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          // Availability Toggle
          _buildAvailabilityToggle(),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          _buildStatsSection(),

          const SizedBox(height: 16),

          // Tab Selector
          _buildTabSelector(),

          const SizedBox(height: 16),

          // Content based on selected tab
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  // ========== AVAILABILITY TOGGLE ==========

  Widget _buildAvailabilityToggle() {
    return GestureDetector(
      onTap: _toggleAvailability,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _isAvailable
              ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
              : Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isAvailable ? const Color(0xFF4CAF50) : Colors.red,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isAvailable ? Icons.check_circle : Icons.cancel,
              color: _isAvailable ? const Color(0xFF4CAF50) : Colors.red,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              _isAvailable ? 'ONLINE' : 'OFFLINE',
              style: GoogleFonts.poppins(
                color: _isAvailable ? const Color(0xFF4CAF50) : Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAvailability() async {
    setState(() {
      _isAvailable = !_isAvailable;
    });

    try {
      await _providerService.toggleAvailability(_isAvailable);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isAvailable
                  ? 'You are now available for bookings'
                  : 'You are now offline',
            ),
            backgroundColor: _isAvailable ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      Log.e(
        'ProviderDashboardScreen',
        'Error toggling availability: $e',
        ex: e,
      );
    }
  }

  // ========== STATS SECTION ==========

  Widget _buildStatsSection() {
    return StreamBuilder<ProviderModel?>(
      stream: _providerService
          .getProviderByUserId(_auth.currentUser!.uid)
          .asStream(),
      builder: (context, providerSnapshot) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.request_quote_rounded,
                  label: 'Pending Offers',
                  value: '5',
                  color: const Color(0xFFFF9800),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.work_outline_rounded,
                  label: 'Active Jobs',
                  value: '3',
                  color: const Color(0xFF2196F3),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Total Earnings',
                  value: '₹12.5K',
                  color: const Color(0xFF4CAF50),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ========== TAB SELECTOR ==========

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabButton('requests', 'Requests', Icons.inbox_rounded),
          _buildTabButton('active', 'Active', Icons.work_outline_rounded),
          _buildTabButton(
            'completed',
            'Done',
            Icons.check_circle_outline_rounded,
          ),
          _buildTabButton(
            'earnings',
            'Earnings',
            Icons.account_balance_wallet_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tab, String label, IconData icon) {
    final isSelected = _selectedTab == tab;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF7A1A) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF7A1A).withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== TAB CONTENT ==========

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'requests':
        return _buildBookingRequestsTab();
      case 'active':
        return _buildActiveJobsTab();
      case 'completed':
        return _buildCompletedJobsTab();
      case 'earnings':
        return _buildEarningsTab();
      default:
        return _buildBookingRequestsTab();
    }
  }

  // ========== BOOKING REQUESTS TAB ==========

  Widget _buildBookingRequestsTab() {
    // This would listen to incoming booking requests for this provider
    // For now, showing a placeholder with instructions

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INCOMING REQUESTS',
            style: GoogleFonts.orbitron(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No new booking requests',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Requests will appear here when customers\nbook services in your area',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== ACTIVE JOBS TAB ==========

  Widget _buildActiveJobsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE JOBS',
            style: GoogleFonts.orbitron(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.work_outline_rounded,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active jobs',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== COMPLETED JOBS TAB ==========

  Widget _buildCompletedJobsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPLETED JOBS',
            style: GoogleFonts.orbitron(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No completed jobs yet',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== EARNINGS TAB ==========

  Widget _buildEarningsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Earnings Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Total Earnings',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹12,500',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'RECENT TRANSACTIONS',
            style: GoogleFonts.orbitron(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: Center(
              child: Text(
                'No transactions yet',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
