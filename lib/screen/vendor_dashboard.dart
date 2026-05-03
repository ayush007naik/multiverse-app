import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/shop_service.dart';
import '../services/logout_service.dart';
import '../services/wallet_service.dart';
import '../providers/order_provider.dart';
import 'add_product_screen.dart';
import 'login_screen.dart';
import '../services/product_service.dart';
import 'package:async/async.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  int _selectedTab = 0;
  bool _shopOpen = true;
  final ShopService _shopService = ShopService();

  // 📦 Incoming Orders - Removed dummy data, using Firestore StreamBuilder
  // Orders are now fetched in _buildHomeTab() using StreamBuilder

  // 🛍️ Products - Using Firestore data via StreamBuilder
  // Products are managed per shop in Firestore

  // 📊 Weekly revenue data - Fetching from Firestore orders
  // Revenue calculated from actual order data

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFFF4D4F),
              onPressed: _addProduct,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: _selectedTab == 0
            ? _buildHomeTab()
            : _selectedTab == 1
            ? _buildProductsTab()
            : _buildAnalyticsTab(),
      ),
    );
  }

  // 🏠 Home Tab
  Widget _buildHomeTab() {
    final user = FirebaseAuth.instance.currentUser;
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: user != null ? _shopService.streamVendorShops(user.uid).first : Future.value([]),
      builder: (context, shopsSnapshot) {
        // Get all shopIds owned by this vendor
        final vendorShopIds = shopsSnapshot.data?.map((shop) => shop['id'] as String).toList() ?? [];
        
        debugPrint('🏪 [VendorDashboard] Vendor has ${vendorShopIds.length} shops: $vendorShopIds');
        
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              _buildShopToggle(),
              _buildStatsRow(),
              _buildSectionHeader('🏪 My Shops', 'Live'),
              _buildVendorShopsSection(),
              _buildSectionHeader('📦 Active Orders', 'Pending'),
              // Active Orders: Show only pending orders
              Consumer<OrderProvider>(
                builder: (context, orderProvider, child) {
                  final vendorId = orderProvider.currentUserId ?? '';
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: orderProvider.streamVendorOrdersByStatus(vendorId, ['pending', 'placed']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        debugPrint('❌ [VendorDashboard] Error loading pending orders: ${snapshot.error}');
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              'Error loading orders: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        );
                      }

                      final pendingOrders = snapshot.data?.docs ?? [];

                      if (pendingOrders.isEmpty) {
                        debugPrint('⚠️ [VendorDashboard] No pending orders for vendor: $vendorId');
                        return _buildEmptyOrders('No pending orders');
                      }

                      debugPrint('✅ [VendorDashboard] Loaded ${pendingOrders.length} pending orders');

                      return Column(
                        children: pendingOrders.map((doc) {
                          final data = doc.data();
                          return _buildOrderCard(data, doc.id);
                        }).toList(),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildSectionHeader('📋 Your Orders', 'In Progress'),
              // Your Orders: Show accepted, preparing, ready orders
              Consumer<OrderProvider>(
                builder: (context, orderProvider, child) {
                  final vendorId = orderProvider.currentUserId ?? '';
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: orderProvider.streamVendorOrdersByStatus(vendorId, ['accepted', 'preparing', 'ready']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        debugPrint('❌ [VendorDashboard] Error loading in-progress orders: ${snapshot.error}');
                        return const SizedBox.shrink();
                      }

                      final yourOrders = snapshot.data?.docs ?? [];

                      if (yourOrders.isEmpty) {
                        debugPrint('⚠️ [VendorDashboard] No in-progress orders for vendor: $vendorId');
                        return _buildEmptyOrders('No orders in progress');
                      }

                      debugPrint('✅ [VendorDashboard] Loaded ${yourOrders.length} orders in progress');

                      return Column(
                        children: yourOrders.map((doc) {
                          final data = doc.data();
                          return _buildYourOrderCard(data, doc.id);
                        }).toList(),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyOrders(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 60,
              color: Colors.grey.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // 🔝 Top Bar
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFFF4D4F).withValues(alpha: 0.3)),
            ),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Text(
                  'M',
                  style: TextStyle(
                    color: Color(0xFFFF4D4F),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MULTIVERSE Vendor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 26,
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4D4F),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Logout button
          PopupMenuButton<String>(
            color: const Color(0xFF1E1E1E),
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutConfirmation();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  /// Show logout confirmation dialog
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Logout?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Color(0xFFAAAAAA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              LogoutService.logoutWithRoute(
                context: context,
                loginScreen: const LoginScreen(),
              );
            },
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
  }

  // 🔛 Shop Toggle
  Widget _buildShopToggle() {
    return GestureDetector(
      onTap: () => setState(() => _shopOpen = !_shopOpen),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: _shopOpen
              ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _shopOpen
                ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                : const Color(0xFF272727),
          ),
        ),
        child: Row(
          children: [
            Text(_shopOpen ? '🟢' : '🔴', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shopOpen ? 'Shop is Open' : 'Shop is Closed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _shopOpen
                      ? 'Accepting orders in Mandi'
                      : 'Tap to open your shop',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Switch(
              value: _shopOpen,
              onChanged: (v) => setState(() => _shopOpen = v),
              activeColor: const Color(0xFF4CAF50),
            ),
          ],
        ),
      ),
    );
  }

  // 📊 Stats
  Widget _buildStatsRow() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Text('Please login', style: TextStyle(color: Colors.white)),
      );
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final orders = snapshot.data?.docs ?? [];
        double vendorEarning = 0;
        int activeOrders = 0;

        for (final doc in orders) {
          final data = doc.data() as Map<String, dynamic>;
          vendorEarning += (data['vendorEarning'] ?? data['total'] ?? data['totalAmount'] ?? 0).toDouble();
          final status = data['status'] as String? ?? '';
          if (status == 'placed' ||
              status == 'preparing' ||
              status == 'ready') {
            activeOrders++;
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: user == null
                ? const Stream<List<Map<String, dynamic>>>.empty()
                : _shopService.streamVendorShops(user.uid),
            builder: (context, shopsSnapshot) {
              final shopCount = shopsSnapshot.data?.length ?? 0;
              final liveCount = (shopsSnapshot.data ?? [])
                  .where((shop) => (shop['isActive'] as bool?) ?? true)
                  .length;

              return Column(
                children: [
                  Row(
                    children: [
                      _statCard(
                        '💰',
                        '₹${vendorEarning.toStringAsFixed(0)}',
                        'Vendor Earnings',
                        0xFFFF4D4F,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        '📦',
                        '$activeOrders',
                        'Active Orders',
                        0xFF2196F3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
              _statCard('🏪', '$shopCount', 'My Shops', 0xFFFF4D4F),
                      const SizedBox(width: 10),
                      _statCard('🟢', '$liveCount', 'Live Shops', 0xFF4CAF50),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildVendorShopsSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildEmptyShopState('Login required to manage shops');
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _shopService.streamVendorShops(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
            ),
          );
        }

        final shops = snapshot.data ?? [];
        if (shops.isEmpty) {
          return _buildEmptyShopState('No shops yet. Add your first shop.');
        }

        return Column(children: shops.map(_buildVendorShopCard).toList());
      },
    );
  }

  Widget _buildEmptyShopState(String message) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272727)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.storefront_outlined,
            color: Color(0xFF888888),
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            'Shop created during signup',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorShopCard(Map<String, dynamic> shop) {
    final isActive =
        (shop['isActive'] as bool?) ?? (shop['open'] as bool?) ?? true;
    final imageUrl = (shop['image'] as String?)?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272727)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildVendorShopFallback(shop),
                  )
                : _buildVendorShopFallback(shop),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shop['name'] as String? ?? 'Shop',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                            : Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? 'Live' : 'Inactive',
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFF4CAF50)
                              : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  shop['category'] as String? ?? 'General',
                  style: const TextStyle(
                    color: Color(0xFFFF4D4F),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF888888),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ShopService.locationLabelFromData(shop),
                        style: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorShopFallback(Map<String, dynamic> shop) {
    return Container(
      width: 64,
      height: 64,
      color: Color(shop['color'] as int? ?? 0xFFFF4D4F).withValues(alpha: 0.15),
      child: Center(
        child: Text(
          shop['icon'] as String? ?? '🏪',
          style: const TextStyle(fontSize: 26),
        ),
      ),
    );
  }

  Widget _statCard(String icon, String val, String label, int color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF272727)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(color).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  val,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String sub) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (sub.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4F).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sub,
                style: const TextStyle(
                  color: Color(0xFFFF4D4F),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 📦 Your Order Card (for Your Orders - Accepted, Preparing, Ready)
  Widget _buildYourOrderCard(Map<String, dynamic> o, String orderId) {
    String status = o['status'] ?? 'pending';
    String customer = o['customer'] ?? 'Customer';
    if (o['address'] != null && o['address'] is Map) {
      customer = o['address']['name'] ?? customer;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getStatusColor(status), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID: #${orderId.toString().substring(0, 6).toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xFFFF4D4F),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            customer,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (o['items'] is List)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (o['items'] as List).map((i) {
                final itemName = (i is Map)
                    ? (i['name'] ?? 'Item')
                    : i.toString();
                final qty = (i is Map) ? (i['qty'] ?? i['quantity'] ?? 1) : 1;
                final price = (i is Map) ? (i['price'] ?? 0) : 0;
                return Text(
                  '• $itemName x$qty - ₹${price * qty}',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ),
          const Divider(color: Color(0xFF272727), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${o['total'] ?? '0'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              // Show action buttons based on status
              if (status == 'accepted')
                _orderActionBtn(
                  'Start Preparing',
                  const Color(0xFFFF4D4F),
                  () => _startPreparing(o, orderId),
                )
              else if (status == 'preparing')
                _orderActionBtn(
                  'Mark as Ready',
                  const Color(0xFF4CAF50),
                  () => _markReady(o, orderId),
                )
              else if (status == 'ready')
                const Text(
                  'Waiting for Delivery',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 📦 Order Card (for Active Orders - Pending)
  Widget _buildOrderCard(Map<String, dynamic> o, String orderId) {
    String status = o['status'] ?? 'pending';
    String customer = o['customer'] ?? 'Customer';
    if (o['address'] != null && o['address'] is Map) {
      customer = o['address']['name'] ?? customer;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getStatusColor(status), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID: #${orderId.toString().substring(0, 6).toUpperCase()}',
                style: const TextStyle(
                  color: Color(0xFFFF4D4F),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            customer,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (o['items'] is List)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (o['items'] as List).map((i) {
                final itemName = (i is Map)
                    ? (i['name'] ?? 'Item')
                    : i.toString();
                final qty = (i is Map) ? (i['qty'] ?? i['quantity'] ?? 1) : 1;
                final price = (i is Map) ? (i['price'] ?? 0) : 0;
                return Text(
                  '• $itemName x$qty - ₹${price * qty}',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ),
          const Divider(color: Color(0xFF272727), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${o['total'] ?? '0'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              // Show Accept/Reject buttons only for pending orders
              Row(
                children: [
                  _orderActionBtn(
                    'Reject',
                    Colors.redAccent,
                    () => _rejectOrder(o, orderId),
                  ),
                  const SizedBox(width: 8),
                  _orderActionBtn(
                    'Accept',
                    Colors.green,
                    () => _acceptOrder(o, orderId),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
      case 'placed':
        return const Color(0xFFFF4D4F); // Red
      case 'accepted':
        return const Color(0xFF2196F3); // Blue
      case 'preparing':
        return const Color(0xFFFF4D4F); // Red
      case 'ready':
        return const Color(0xFF4CAF50); // Green
      case 'out_for_delivery':
        return const Color(0xFF9C27B0); // Purple
      case 'delivered':
        return const Color(0xFF00BCD4); // Cyan
      case 'cancelled':
      case 'rejected':
        return const Color(0xFFE53935); // Red
      default:
        return const Color(0xFF888888); // Grey
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
      case 'placed':
        return 'PENDING';
      case 'accepted':
        return 'ACCEPTED';
      case 'preparing':
        return 'PREPARING';
      case 'ready':
        return 'READY';
      case 'out_for_delivery':
        return 'OUT FOR DELIVERY';
      case 'delivered':
        return 'DELIVERED';
      case 'cancelled':
      case 'rejected':
        return 'CANCELLED';
      default:
        return status.toUpperCase();
    }
  }

  Widget _orderActionBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 🛍️ Products Tab
  Widget _buildProductsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Text(
            '🛍️ My Products',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ProductService().streamVendorProducts(user.uid),
            builder: (context, snapshot) {
              // Show loading indicator while waiting for data
              if (snapshot.connectionState == ConnectionState.waiting) {
                print('⏳ [VendorDashboard] Products loading for vendor: ${user.uid}');
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
                );
              }

              // Handle errors with detailed logging
              if (snapshot.hasError) {
                print('❌ [VendorDashboard] ERROR loading products:');
                print('   Error: ${snapshot.error}');
                print('   Stack Trace: ${snapshot.stackTrace}');
                print('   Vendor ID: ${user.uid}');
                
                // Check if it's a missing index error
                final isIndexError = ProductService.isMissingIndexError(snapshot.error);
                final indexUrl = ProductService.extractIndexCreationUrl(snapshot.error);
                
                if (isIndexError) {
                  print('⚠️ [VendorDashboard] MISSING INDEX ERROR DETECTED!');
                  if (indexUrl != null) {
                    print('🔗 [VendorDashboard] Index Creation URL: $indexUrl');
                  }
                  
                  // Auto-show index creation dialog
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ProductService.showIndexCreationDialog(
                      context: context,
                      error: snapshot.error,
                      onRetry: () {
                        setState(() {});
                      },
                    );
                  });
                }
                
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isIndexError ? Icons.cloud_off : Icons.error_outline,
                        size: 64,
                        color: isIndexError ? const Color(0xFFFF4D4F) : Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isIndexError ? 'Index Required' : 'Error loading products',
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isIndexError 
                            ? 'Creating index...\nProducts will appear shortly' 
                            : '${snapshot.error}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4D4F),
                              foregroundColor: Colors.white,
                            ),
                          ),
                          if (indexUrl != null) const SizedBox(width: 12),
                          if (indexUrl != null)
                            ElevatedButton.icon(
                              onPressed: () {
                                ProductService.showIndexCreationDialog(
                                  context: context,
                                  error: snapshot.error,
                                  onRetry: () => setState(() {}),
                                );
                              },
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Create Index'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF4D4F),
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              final products = snapshot.data?.docs ?? [];
              print('✅ [VendorDashboard] Loaded ${products.length} products');
              if (products.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No products added yet',
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addProduct,
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Product'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D4F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index].data();
                  final productId = products[index].id;
                  final isActive = product['isActive'] ?? true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF272727)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D0D0D),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: product['imageUrl'] != null &&
                                product['imageUrl'].toString().isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  product['imageUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, _, __) => const Icon(
                                      Icons.shopping_bag_outlined,
                                      color: Colors.grey),
                                ),
                              )
                            : const Icon(Icons.shopping_bag_outlined,
                                color: Colors.grey),
                      ),
                      title: Text(
                        product['name'] ?? 'Unnamed Product',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '₹${product['price']}',
                            style: const TextStyle(
                              color: Color(0xFFFF4D4F),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            product['category'] ?? 'Uncategorized',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        color: const Color(0xFF1E1E1E),
                        onSelected: (value) async {
                          final shopId = product['shopId']?.toString() ?? '';
                          if (value == 'delete' && shopId.isNotEmpty) {
                            await ProductService().deleteProduct(shopId, productId);
                          } else if (value == 'toggle' && shopId.isNotEmpty) {
                            await ProductService()
                                .toggleProductStatus(shopId, productId, !isActive);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              isActive ? 'Mark Out of Stock' : 'Mark In Stock',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete Product',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // 📊 Analytics Tab
  Widget _buildAnalyticsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Login required", style: TextStyle(color: Colors.white)));

    return StreamBuilder<List<QuerySnapshot>>(
      stream: StreamZip([
        // Orders stream
        FirebaseFirestore.instance
            .collection('orders')
            .where('vendorId', isEqualTo: user.uid)
            .snapshots(),
        // Products stream for the vendor
        FirebaseFirestore.instance
            .collection('products')
            .where('vendorId', isEqualTo: user.uid)
            .snapshots(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
          );
        }

        final ordersSnapshot = snapshot.data?[0];
        final productsSnapshot = snapshot.data?[1];

        final orders = ordersSnapshot?.docs ?? [];
        final products = productsSnapshot?.docs ?? [];

        // Create product map for efficient lookup
        final productMap = <String, Map<String, dynamic>>{};
        for (final doc in products) {
          final data = doc.data() as Map<String, dynamic>;
          productMap[doc.id] = {
            'name': data['name'] ?? 'Unknown Product',
            'price': (data['price'] as num?)?.toDouble() ?? 0.0,
            'imageUrl': data['imageUrl'] ?? data['image'],
          };
        }

        // Data processing for analytics
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final weekStart = now.subtract(const Duration(days: 7));

        double todayRevenue = 0;
        double weekRevenue = 0;
        int todayTotalOrders = 0;
        int todayDelivered = 0;
        int todayCancelled = 0;

        // For Weekly Revenue Chart
        final weekDataMap = <String, double>{};
        for (int i = 6; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          weekDataMap[DateFormat('EEE').format(date)] = 0.0;
        }

        // For Top Products
        final productStats = <String, Map<String, dynamic>>{};

        for (final doc in orders) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status']?.toString().toLowerCase() ?? '';
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? now;
          final isDelivered = status == 'delivered';
          final isCancelled = status == 'cancelled' || status == 'rejected';

          // Summary calculations
          if (createdAt.isAfter(todayStart)) {
            todayTotalOrders++;
            if (isDelivered) todayDelivered++;
            if (isCancelled) todayCancelled++;
          }

          if (isDelivered) {
            // Revenue calculations
            final items = data['items'] as List<dynamic>? ?? [];
            double orderRevenue = 0;
            
            for (final item in items) {
              if (item is Map<String, dynamic>) {
                final productId = item['productId']?.toString() ?? '';
                final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                final subtotal = qty * price;
                orderRevenue += subtotal;

                // Product tracking - use productId from order items
                if (productId.isNotEmpty) {
                  if (!productStats.containsKey(productId)) {
                    final productData = productMap[productId];
                    productStats[productId] = {
                      'name': productData?['name'] ?? item['name']?.toString() ?? 'Unknown Product',
                      'sold': 0,
                      'revenue': 0.0,
                      'icon': productData?['imageUrl'] ?? item['image'] ?? item['icon'] ?? '📦',
                    };
                  }
                  productStats[productId]!['sold'] = (productStats[productId]!['sold'] as int) + qty;
                  productStats[productId]!['revenue'] = (productStats[productId]!['revenue'] as double) + subtotal;
                }
              }
            }

            if (createdAt.isAfter(todayStart)) todayRevenue += orderRevenue;
            if (createdAt.isAfter(weekStart)) weekRevenue += orderRevenue;

            // Weekly chart data
            final dayKey = DateFormat('EEE').format(createdAt);
            if (weekDataMap.containsKey(dayKey)) {
              weekDataMap[dayKey] = weekDataMap[dayKey]! + orderRevenue;
            }
          }
        }

        // Finalize Weekly Chart Data
        final weekData = weekDataMap.entries.map((e) => {'day': e.key, 'amt': e.value.toInt()}).toList();
        final maxAmt = weekData.isEmpty ? 1.0 : weekData.map((d) => d['amt'] as int).reduce((a, b) => a > b ? a : b).toDouble();

        // Finalize Top Products
        final sortedTopProducts = productStats.entries.toList();
        sortedTopProducts.sort((a, b) => (b.value['sold'] as int).compareTo(a.value['sold'] as int));
        final top3 = sortedTopProducts.take(3).toList();

        if (orders.isEmpty) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Text(
                    '📊 Analytics',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                _buildPayoutCard(),
                const SizedBox(height: 60),
                const Center(child: Text('No data yet', style: TextStyle(color: Colors.grey, fontSize: 16))),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  '📊 Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildPayoutCard(),
              
              // Revenue Cards
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    _revenueCard('Today', '₹${todayRevenue.toStringAsFixed(0)}', 'Live'),
                    const SizedBox(width: 12),
                    _revenueCard('This Week', '₹${weekRevenue.toStringAsFixed(0)}', 'Last 7d'),
                  ],
                ),
              ),

              // Weekly Revenue Chart
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF272727)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weekly Revenue',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 130,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: weekData.map((d) {
                            final amt = d['amt'] as int;
                            final h = maxAmt > 0 ? (amt / maxAmt) * 110 : 0.0;
                            final isToday = d['day'] == DateFormat('EEE').format(now);
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  amt >= 1000 ? '₹${(amt / 1000).toStringAsFixed(1)}k' : '₹$amt',
                                  style: TextStyle(
                                    color: isToday ? const Color(0xFFFF4D4F) : const Color(0xFF888888),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 30,
                                  height: h.clamp(2.0, 110.0),
                                  decoration: BoxDecoration(
                                    color: isToday ? const Color(0xFFFF4D4F) : const Color(0xFF333333),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  d['day'] as String,
                                  style: TextStyle(
                                    color: isToday ? Colors.white : const Color(0xFF888888),
                                    fontSize: 10,
                                    fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Top Products Section
              _buildSectionHeader('🏆 Top Products', ''),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: top3.isEmpty 
                  ? const Center(child: Text('No products sold yet', style: TextStyle(color: Colors.grey)))
                  : Column(
                      children: top3.map((entry) {
                        final pData = entry.value;
                        return _topProduct(
                          pData['icon'],
                          pData['name'],
                          pData['sold'],
                          '₹${(pData['revenue'] as double).toStringAsFixed(0)}'
                        );
                      }).toList(),
                    ),
              ),

              // Today's Summary
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF272727)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Summary",
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      _summaryRow('📦 Orders Received', '$todayTotalOrders'),
                      _summaryRow('✅ Delivered', '$todayDelivered'),
                      _summaryRow('🚫 Cancelled', '$todayCancelled'),
                      const Divider(color: Color(0xFF272727), height: 20),
                      _summaryRow('💰 Net Revenue', '₹${todayRevenue.toStringAsFixed(0)}', bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPayoutCard() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wallets')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final balance = (data?['balance'] as num?)?.toDouble() ?? 0;

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF272727)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Color(0xFFFF4D4F),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Wallet & Payout',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '₹${balance.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFFFF4D4F),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: balance <= 0
                      ? null
                      : () => _requestWithdrawal(balance),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Request Withdrawal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D4F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              _buildLatestPayout(user.uid),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLatestPayout(String vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payout_requests')
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        final doc = snapshot.data?.docs.isNotEmpty == true
            ? snapshot.data!.docs.first
            : null;
        if (doc == null) return const SizedBox.shrink();
        final data = doc.data() as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Latest payout: ${data['status']} · ₹${((data['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
          ),
        );
      },
    );
  }

  Future<void> _requestWithdrawal(double maxAmount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final controller = TextEditingController(
      text: maxAmount.toStringAsFixed(0),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Request Withdrawal',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Amount',
            labelStyle: TextStyle(color: Colors.grey),
            prefixText: '₹',
            prefixStyle: TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Request'),
          ),
        ],
      ),
    );

    if (amount == null) return;
    try {
      await WalletService().requestPayout(vendorId: user.uid, amount: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payout request submitted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payout failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _revenueCard(String label, String val, String change) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF272727)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              val,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              change,
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topProduct(dynamic icon, String name, int sold, String revenue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF272727)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: (icon is String && (icon.startsWith('http') || icon.startsWith('https')))
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      icon,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, __) => const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      icon is String ? icon : '📦',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$sold units sold',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            revenue,
            style: const TextStyle(
              color: Color(0xFFFF4D4F),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String val, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? Colors.white : const Color(0xFF888888),
              fontSize: bold ? 14 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            val,
            style: TextStyle(
              color: bold ? const Color(0xFFFF4D4F) : Colors.white,
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Actions
  void _acceptOrder(Map<String, dynamic> o, String orderId) async {
    try {
      await Provider.of<OrderProvider>(context, listen: false).confirmOrder(orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Order accepted! Start preparing.'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      debugPrint("Error accepting order: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error accepting order'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _startPreparing(Map<String, dynamic> o, String orderId) async {
    try {
      await Provider.of<OrderProvider>(context, listen: false).startPreparingOrder(orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🍳 Preparing order...'),
          backgroundColor: Color(0xFFFF4D4F),
        ),
      );
    } catch (e) {
      debugPrint("Error starting preparation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating order'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _rejectOrder(Map<String, dynamic> o, String orderId) async {
    try {
      await Provider.of<OrderProvider>(context, listen: false).cancelOrder(orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order rejected.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      debugPrint("Error cancelling order: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error rejecting order'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _markReady(Map<String, dynamic> o, String orderId) async {
    try {
      await Provider.of<OrderProvider>(context, listen: false).markOrderReady(orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📦 Order ready! Waiting for delivery partner.'),
          backgroundColor: Color(0xFF2196F3),
        ),
      );
    } catch (e) {
      debugPrint("Error marking order ready: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating order'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // 🛍️ Add Product Screen
  void _addProduct() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to add products'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Get vendor's shops from the stream first
    final shopsSnapshot = await _shopService.streamVendorShops(user.uid).first;
    
    if (shopsSnapshot.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shop not found. Please contact support.'),
          backgroundColor: const Color(0xFFFF4D4F),
        ),
      );
      return;
    }

    // If only one shop, use it directly
    if (shopsSnapshot.length == 1) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddProductScreen(shopId: shopsSnapshot.first['id'] as String),
        ),
      );
      
      if (result == true) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product added successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
      return;
    }

    // Multiple shops - show selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Select Shop',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: shopsSnapshot.length,
            itemBuilder: (context, index) {
              final shop = shopsSnapshot[index];
              return ListTile(
                title: Text(
                  shop['name'] as String,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  shop['category'] as String? ?? 'Shop',
                  style: const TextStyle(color: Color(0xFFAAAAAA)),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddProductScreen(
                        shopId: shop['id'] as String,
                      ),
                    ),
                  );
                  
                  if (result == true) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Product added successfully!'),
                        backgroundColor: Color(0xFF4CAF50),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // 🔘 Bottom Nav
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedTab,
      onTap: (i) => setState(() => _selectedTab = i),
      backgroundColor: const Color(0xFF111111),
      selectedItemColor: const Color(0xFFFF4D4F),
      unselectedItemColor: const Color(0xFF555555),
      selectedFontSize: 11,
      unselectedFontSize: 11,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_rounded),
          label: 'Products',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_rounded),
          label: 'Analytics',
        ),
      ],
    );
  }
}
