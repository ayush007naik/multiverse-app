import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/cyberpunk_theme.dart';
import 'dashboard/counter_booking_tab.dart';
import 'dashboard/overview_tab.dart';
import 'dashboard/movies_tab.dart';
import 'dashboard/shows_tab.dart';
import 'dashboard/seat_layout_tab.dart';
import 'dashboard/bookings_tab.dart';
import 'dashboard/analytics_tab.dart';
import 'dashboard/payout_tab.dart';
import 'dashboard/coupons_tab.dart';
import 'dashboard/settings_tab.dart';
import 'dashboard/staff_tab.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const OverviewTab(),
    const MoviesTab(),
    const ShowsTab(),
    const CounterBookingTab(),
    const SeatLayoutTab(),
    const BookingsTab(),
    const StaffTab(),
    const AnalyticsTab(),
    const PayoutTab(),
    const CouponsTab(),
    const SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theatreData = authProvider.theatreData;

    if (authProvider.isLoading) {
      return const Scaffold(
        backgroundColor: CyberpunkTheme.darkBg,
        body: Center(child: CircularProgressIndicator(color: CyberpunkTheme.primaryNeon)),
      );
    }

    if (theatreData?['status'] == 'pending') {
      return const PendingApprovalScreen();
    }

    if (theatreData?['status'] == 'rejected') {
      return const RejectedScreen();
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            backgroundColor: CyberpunkTheme.black,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.selected,
            selectedIconTheme: const IconThemeData(color: CyberpunkTheme.primaryNeon),
            unselectedIconTheme: const IconThemeData(color: Colors.white24),
            selectedLabelTextStyle: const TextStyle(color: CyberpunkTheme.primaryNeon, fontSize: 11),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white24, fontSize: 11),
            minWidth: 56,
            minExtendedWidth: 80,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: theatreData?['logoUrl'] != null && theatreData!['logoUrl'].toString().isNotEmpty
                  ? Image.network(
                      theatreData['logoUrl'],
                      width: 40,
                      errorBuilder: (_, __, ___) => const Icon(Icons.movie, color: CyberpunkTheme.primaryNeon),
                    )
                  : const Icon(Icons.movie, color: CyberpunkTheme.primaryNeon),
            ),
            destinations: [
              _buildDestination(Icons.dashboard_outlined, Icons.dashboard, 'Overview', 0),
              _buildDestination(Icons.movie_outlined, Icons.movie, 'Movies', 1),
              _buildDestination(Icons.calendar_month_outlined, Icons.calendar_month, 'Shows', 2),
              _buildDestination(Icons.confirmation_num_outlined, Icons.confirmation_num, 'Counter', 3),
              _buildDestination(Icons.grid_view_outlined, Icons.grid_view, 'Seats', 4),
              _buildDestination(Icons.history_outlined, Icons.history, 'Bookings', 5),
              _buildDestination(Icons.people_outlined, Icons.people, 'Staff', 6),
              _buildDestination(Icons.analytics_outlined, Icons.analytics, 'Analytics', 7),
              _buildDestination(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Payout', 8),
              _buildDestination(Icons.local_offer_outlined, Icons.local_offer, 'Offers', 9),
              _buildDestination(Icons.settings_outlined, Icons.settings, 'Settings', 10),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white24),
                  onPressed: () => Provider.of<AuthProvider>(context, listen: false).logout(),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),
          // Main Content
          Expanded(
            child: Container(
              color: CyberpunkTheme.darkBg,
              child: IndexedStack(
            index: _selectedIndex,
            children: _tabs,
          ),
            ),
          ),
        ],
      ),
    );
  }

  NavigationRailDestination _buildDestination(
    IconData icon,
    IconData selectedIcon,
    String label,
    int index,
  ) {
    return NavigationRailDestination(
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon),
      label: Text(label),
    );
  }
}

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [CyberpunkTheme.darkBg, CyberpunkTheme.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: CyberpunkTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.05),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: const Icon(Icons.hourglass_top, color: Colors.amber, size: 40),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'AWAITING APPROVAL',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your theatre account is under review by our admin team. '
                      'You will receive a notification once it is approved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Status', style: TextStyle(color: Colors.white38, fontSize: 12)),
                              Text('PENDING REVIEW', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Est. Time', style: TextStyle(color: Colors.white38, fontSize: 12)),
                              Text('Within 2 Hours', style: TextStyle(color: CyberpunkTheme.primaryNeon, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Provider.of<AuthProvider>(context, listen: false).logout(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white12),
                        ),
                        child: const Text('LOGOUT'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RejectedScreen extends StatelessWidget {
  const RejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theatreData = Provider.of<AuthProvider>(context).theatreData;
    final reason = theatreData?['rejectionReason'] ?? 'Your application did not meet our requirements.';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [CyberpunkTheme.darkBg, CyberpunkTheme.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(40),
            margin: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: CyberpunkTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cancel_outlined, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'APPLICATION REJECTED',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Provider.of<AuthProvider>(context, listen: false).logout(),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('LOGOUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
