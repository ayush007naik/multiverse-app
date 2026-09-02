import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/logging_service.dart';
import '../services/vendor_service.dart';
import '../services/web_notification_service.dart';
import '../models/vendor_model.dart';
import 'vendor_login_screen.dart';
import 'vendor_home_screen.dart';
import 'vendor_products_screen.dart';
import 'vendor_orders_screen.dart';
import 'vendor_inventory_screen.dart';
import 'vendor_offers_screen.dart';
import 'vendor_analytics_screen.dart';
import 'vendor_earnings_screen.dart';
import 'vendor_notifications_screen.dart';
import 'vendor_settings_screen.dart';

class VendorDashboardMain extends StatefulWidget {
  const VendorDashboardMain({super.key});

  @override
  State<VendorDashboardMain> createState() => _VendorDashboardMainState();
}

class _VendorDashboardMainState extends State<VendorDashboardMain>
    with SingleTickerProviderStateMixin {
  final _vendorService = VendorService();
  int _selectedIndex = 0;
  final bool _isSidebarExpanded = true;
  late AnimationController _animationController;
  final List<DashboardModule> _modules = [
    DashboardModule(
      icon: Icons.dashboard,
      title: 'Dashboard',
      screen: const VendorHomeScreen(),
    ),
    DashboardModule(
      icon: Icons.shopping_bag,
      title: 'Products',
      screen: const VendorProductsScreen(),
    ),
    DashboardModule(
      icon: Icons.receipt_long,
      title: 'Orders',
      screen: const VendorOrdersScreen(),
    ),
    DashboardModule(
      icon: Icons.inventory,
      title: 'Inventory',
      screen: const VendorInventoryScreen(),
    ),
    DashboardModule(
      icon: Icons.local_offer,
      title: 'Offers',
      screen: const VendorOffersScreen(),
    ),
    DashboardModule(
      icon: Icons.analytics,
      title: 'Analytics',
      screen: const VendorAnalyticsScreen(),
    ),
    DashboardModule(
      icon: Icons.account_balance_wallet,
      title: 'Earnings',
      screen: const VendorEarningsScreen(),
    ),
    DashboardModule(
      icon: Icons.notifications,
      title: 'Notifications',
      screen: const VendorNotificationsScreen(),
    ),
    DashboardModule(
      icon: Icons.settings,
      title: 'Settings',
      screen: const VendorSettingsScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // Initialize web notifications
    _initializeWebNotifications();
  }

  Future<void> _initializeWebNotifications() async {
    try {
      await WebNotificationService().initialize();
    } catch (e) {
      Log.w('VendorDashboardMain', 'Failed to initialize web notifications: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Logout?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Color(0xFFAAAAAA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _vendorService.logout();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const VendorLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const VendorLoginScreen();
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar - Cyberpunk Style
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            width: _isSidebarExpanded ? 260 : 85,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A0B2E),
                  Color(0xFF0D0518),
                  Color(0xFF08090D),
                ],
              ),
              border: Border(
                right: BorderSide(
                  color: const Color(0xFFFF6A00).withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6A00).withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSidebarHeader(),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF6A00).withValues(alpha: 0.5),
                        const Color(0xFF9C27B0).withValues(alpha: 0.3),
                        const Color(0xFFFF6A00).withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
                Expanded(child: _buildSidebarMenu()),
                _buildSidebarFooter(),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildTopNavbar(),
                Expanded(child: _modules[_selectedIndex].screen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF6A00).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6A00).withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6A00), Color(0xFFFF9800)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6A00).withValues(alpha: 0.6),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.store, color: Colors.white, size: 30),
          ),
          if (_isSidebarExpanded) ...[
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF6A00), Color(0xFFFF9800)],
                    ).createShader(bounds),
                    child: const Text(
                      'MULTIVERSE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const Text(
                    'VENDOR PORTAL',
                    style: TextStyle(
                      color: Color(0xFF9C27B0),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarMenu() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _modules.length,
      itemBuilder: (context, index) {
        final module = _modules[index];
        final isSelected = _selectedIndex == index;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => setState(() => _selectedIndex = index),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: _isSidebarExpanded ? 14 : 16,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFFFF6A00), Color(0xFFFF9800)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                          width: 1,
                        ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFFF6A00,
                            ).withValues(alpha: 0.5),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      module.icon,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF9C27B0),
                      size: 24,
                    ),
                    if (_isSidebarExpanded) ...[
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          module.title,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFAAAAAA),
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logout Button - Cyberpunk Style
          InkWell(
            onTap: _logout,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFFF5252)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'LOGOUT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
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

  Widget _buildTopNavbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D0518), Color(0xFF1A0B2E)],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF6A00).withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6A00).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFF6A00), Color(0xFFFF9800)],
            ).createShader(bounds),
            child: const Text(
              'DASHBOARD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const Spacer(),
          StreamBuilder<VendorModel?>(
            stream: _vendorService.streamVendorData(
              FirebaseAuth.instance.currentUser!.uid,
            ),
            builder: (context, snapshot) {
              final vendor = snapshot.data;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0B2E).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: (vendor?.isShopOpen ?? false)
                            ? const Color(0xFF00E676)
                            : const Color(0xFFFF5252),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                ((vendor?.isShopOpen ?? false)
                                        ? const Color(0xFF00E676)
                                        : const Color(0xFFFF5252))
                                    .withValues(alpha: 0.8),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      vendor?.shopName ?? 'Shop',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFF9C27B0),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6A00), Color(0xFFFF9800)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF6A00,
                            ).withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF0D0518),
                        child: Text(
                          (vendor?.ownerName ?? 'V')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class DashboardModule {
  final IconData icon;
  final String title;
  final Widget screen;

  DashboardModule({
    required this.icon,
    required this.title,
    required this.screen,
  });
}
