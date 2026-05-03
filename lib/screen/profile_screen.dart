// 📁 lib/screens/profile_screen.dart
// ✅ Profile Screen for MULTIVERSE — Mandi, Himachal Pradesh

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'admin_screen.dart';
import '../services/settings_service.dart';
import 'about_screen.dart';
import 'all_orders_screen.dart';
import 'help_support_screen.dart';
import 'login_screen.dart';
import 'payment_methods_screen.dart';
import 'saved_addresses_screen.dart';
import 'settings_screen.dart';
import '../widgets/premium_ui_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final SettingsService _settingsService = SettingsService();

  bool _notificationsOn = true;
  bool _locationOn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            FadeSlideAnimation(
              delay: const Duration(milliseconds: 100),
              child: _buildProfileCard(),
            ),
            FadeSlideAnimation(
              delay: const Duration(milliseconds: 200),
              child: _buildWalletCard(),
            ),
            FadeSlideAnimation(
              delay: const Duration(milliseconds: 300),
              child: _buildStats(),
            ),
            FadeSlideAnimation(
              delay: const Duration(milliseconds: 400),
              child: _buildOrderHistory(),
            ),
            FadeSlideAnimation(
              delay: const Duration(milliseconds: 500),
              child: _buildSettings(),
            ),
            FadeSlideAnimation(
              delay: const Duration(milliseconds: 600),
              child: _buildLogout(),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
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

        return GlassCard(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          padding: const EdgeInsets.all(18),
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
                  const Text(
                    'Wallet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${balance.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFFFF4D4F),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('wallets')
                    .doc(user.uid)
                    .collection('transactions')
                    .orderBy('createdAt', descending: true)
                    .limit(3)
                    .snapshots(),
                builder: (context, txSnapshot) {
                  final transactions = txSnapshot.data?.docs ?? [];
                  if (transactions.isEmpty) {
                    return const Text(
                      'No wallet transactions yet',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 12),
                    );
                  }

                  return Column(
                    children: transactions.map((doc) {
                      final tx = doc.data() as Map<String, dynamic>;
                      final type = tx['type'] as String? ?? 'credit';
                      final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
                      final isCredit = type == 'credit';
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              isCredit
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: isCredit ? Colors.green : Colors.redAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tx['description'] as String? ??
                                    tx['source'] as String? ??
                                    'Wallet transaction',
                                style: const TextStyle(
                                  color: Color(0xFFAAAAAA),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: isCredit
                                    ? Colors.green
                                    : Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 👤 Profile Card
  Widget _buildProfileCard() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final name = userData?['name'] as String? ?? user.displayName ?? 'User';
        final phone = userData?['phone'] as String? ?? user.phoneNumber ?? 'Not set';
        final email = userData?['email'] as String? ?? user.email ?? 'Not set';
        final createdAt = userData?['createdAt'] as Timestamp?;
        final memberSince = createdAt != null
            ? _formatMemberSince(createdAt)
            : 'Recently joined';

        return GlassCard(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                    Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF272727)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0D0D0D),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFFF4D4F),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            email,
                            style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                          Container(
                           padding: const EdgeInsets.symmetric(
                             horizontal: 7,
                             vertical: 2,
                           ),
                           decoration: BoxDecoration(
                             color: const Color(0xFFFF4D4F).withValues(alpha: 0.15),
                             borderRadius: BorderRadius.circular(6),
                           ),
                          child: Text(
                            '⭐ $memberSince',
                            style: const TextStyle(
                              color: Color(0xFFFF4D4F),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
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
      },
    );
  }

  String _formatMemberSince(Timestamp timestamp) {
    final date = timestamp.toDate();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  // 📊 Stats Row
  Widget _buildStats() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final orders = snapshot.data?.docs ?? [];
        final delivered = orders.where((o) {
          final data = o.data() as Map<String, dynamic>;
          return data['status'] == 'delivered';
        }).length;
        
        final totalSpent = orders
            .where((o) {
              final data = o.data() as Map<String, dynamic>;
              return data['status'] == 'delivered';
            })
            .fold<double>(0, (runningTotal, o) {
              final data = o.data() as Map<String, dynamic>;
              return runningTotal + ((data['total'] as num?)?.toDouble() ?? 0);
            });

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _statCard('📦', '$delivered', 'Orders'),
              const SizedBox(width: 12),
              _statCard('💸', '₹${totalSpent.toStringAsFixed(0)}', 'Total Spent'),
              const SizedBox(width: 12),
              _statCard('⭐', '4.8', 'Avg Rating'),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String icon, String value, String label) {
    return Expanded(
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 16),
        borderRadius: 14,
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // 📦 Order History
  Widget _buildOrderHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📦 Order History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Search by shop, status, or price...",
              hintStyle: const TextStyle(color: Color(0xFF555555)),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFFFF4D4F),
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Color(0xFFFF4D4F),
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = "";
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[900],
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('userId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          color: Color(0xFF333333),
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No orders matching "$_searchQuery"'
                              : 'No orders yet',
                          style: const TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              var orders = snapshot.data!.docs;
              // Filter by search query
              if (_searchQuery.isNotEmpty) {
                orders = orders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final shopName = (data['shopName'] ?? '').toString().toLowerCase();
                  final status = (data['status'] ?? '').toString().toLowerCase();
                  final total = (data['total'] ?? 0).toString();
                  final query = _searchQuery.toLowerCase();
                  
                  return shopName.contains(query) ||
                      status.contains(query) ||
                      total.contains(query);
                }).toList();
              }

              if (orders.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Text(
                      'No orders matching "$_searchQuery"',
                      style: const TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }

              final displayOrders = orders.take(2).toList();
              final hasMore = orders.length > 2;

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${orders.length} orders',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                      if (hasMore)
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AllOrdersScreen(
                                  orders: orders.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    data['id'] = doc.id;
                                    return data;
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              color: Color(0xFFFF4D4F),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...displayOrders.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return _buildOrderCard(data);
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> o) {
    final status = (o['status'] as String? ?? 'placed').toLowerCase();
    final statusColor = _getStatusColor(status);
    final shopName = o['shopName'] as String? ?? 'Unknown Shop';
    final total = (o['total'] as num?)?.toDouble() ?? 0;
    final itemCount = (o['items'] as List?)?.length ?? 0;
    final createdAt = o['createdAt'] as Timestamp?;
    final dateStr = createdAt != null ? _formatOrderDate(createdAt) : 'Recently';
    final category = o['shopCategory'] as String? ?? '';
    final icon = _getCategoryIcon(category);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                icon,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$itemCount items · ₹${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '#${o['id'].toString().substring(0, 8)}',
                style: const TextStyle(color: Color(0xFF555555), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return const Color(0xFF4CAF50);
      case 'cancelled':
        return const Color(0xFFE53935);
      case 'placed':
      case 'pending':
        return const Color(0xFFFF4D4F);
      case 'preparing':
        return const Color(0xFF2196F3);
      case 'ready':
      case 'picked':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF888888);
    }
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'grocery':
        return '🛒';
      case 'pharmacy':
        return '💊';
      case 'clothing':
        return '👔';
      case 'food':
      case 'restaurant':
        return '🍽️';
      case 'electronics':
        return '📱';
      case 'hardware':
        return '🔨';
      case 'beauty':
        return '🧴';
      default:
        return '🏪';
    }
  }

  String _formatOrderDate(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  // ⚙️ Settings
  Widget _buildSettings() {
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚙️ Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot>(
            stream: user == null
                ? const Stream<DocumentSnapshot>.empty()
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
            builder: (context, snapshot) {
              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              final role = userData?['role'] as String? ?? 'user';

              if (role != 'admin') return const SizedBox.shrink();

              return Column(
                children: [
                  _settingTile(
                    icon: Icons.admin_panel_settings_rounded,
                    iconColor: 0xFFF44336,
                    title: 'Admin Panel',
                    subtitle: 'Manage shops, users, and analytics',
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF444444),
                      size: 14,
                    ),
                    onTap: () {
                      if (user == null) return;
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      // Security double-check: verify role again before navigation
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .get()
                          .then((doc) {
                        if (doc.data()?['role'] == 'admin') {
                          navigator.push(
                            MaterialPageRoute(
                                builder: (_) => const AdminScreen()),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Access Denied: Admin role required'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      });
                    },
                  ),
                ],
              );
            },
          ),
          _settingTile(
            icon: Icons.location_on_rounded,
            iconColor: 0xFF4CAF50,
            title: 'Location Access',
            subtitle: 'Allow for faster delivery',
            trailing: Switch(
              value: _locationOn,
              onChanged: (v) => setState(() => _locationOn = v),
              activeThumbColor: const Color(0xFFFF4D4F),
            ),
          ),
          _settingTile(
            icon: Icons.notifications_rounded,
            iconColor: 0xFF2196F3,
            title: 'Notifications',
            subtitle: 'Order updates & offers',
            trailing: Switch(
              value: _notificationsOn,
              onChanged: (v) => setState(() => _notificationsOn = v),
              activeThumbColor: const Color(0xFFFF4D4F),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: user == null
                ? const Stream<QuerySnapshot>.empty()
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('addresses')
                      .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final defaultAddress = docs
                  .map((doc) => doc.data() as Map<String, dynamic>)
                  .cast<Map<String, dynamic>?>()
                  .firstWhere(
                    (address) => address?['isDefault'] == true,
                    orElse: () => docs.isNotEmpty
                        ? docs.first.data() as Map<String, dynamic>
                        : null,
                  );
              final subtitle = docs.isEmpty
                  ? 'No saved addresses'
                  : '${docs.length} saved · ${(defaultAddress?['city'] as String?) ?? 'Default selected'}';

              return _settingTile(
                icon: Icons.location_city_rounded,
                iconColor: 0xFFFF4D4F,
                title: 'Saved Addresses',
                subtitle: subtitle,
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF444444),
                  size: 14,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SavedAddressesScreen(),
                    ),
                  );
                },
              );
            },
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _settingsService.streamPaymentMethods(),
            builder: (context, snapshot) {
              final methods = snapshot.data ?? [];
              final defaultMethod = methods
                  .cast<Map<String, dynamic>?>()
                  .firstWhere(
                    (method) => method?['isDefault'] == true,
                    orElse: () => methods.isNotEmpty ? methods.first : null,
                  );
              return _settingTile(
                icon: Icons.payment_rounded,
                iconColor: 0xFF9C27B0,
                title: 'Payment Methods',
                subtitle: defaultMethod == null
                    ? 'No saved payment methods'
                    : SettingsService.paymentMethodLabel(defaultMethod),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF444444),
                  size: 14,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaymentMethodsScreen(),
                    ),
                  );
                },
              );
            },
          ),
          _settingTile(
            icon: Icons.help_outline_rounded,
            iconColor: 0xFF00BCD4,
            title: 'Help & Support',
            subtitle: 'WhatsApp, call, email',
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF444444),
              size: 14,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
              );
            },
          ),
          _settingTile(
            icon: Icons.info_outline_rounded,
            iconColor: 0xFF607D8B,
            title: 'About Multiverse',
            subtitle: 'Version 1.0.0+1 · Developer info',
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF444444),
              size: 14,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required int iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        borderRadius: 14,
        child: Row(
          children: [
             Container(
               width: 38,
               height: 38,
               decoration: BoxDecoration(
                 color: Color(iconColor).withValues(alpha: 0.15),
                 borderRadius: BorderRadius.circular(10),
               ),
              child: Icon(icon, color: Color(iconColor), size: 20),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  // 🚪 Logout Button
  Widget _buildLogout() {
    return Column(
      children: [
        const SizedBox(height: 30),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
               shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(16),
               ),
               elevation: 4,
               shadowColor: Colors.red.withValues(alpha: 0.4),
             ),
            onPressed: () {
              _confirmLogout();
            },
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text(
              "Logout Account",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✏️ Edit Profile Dialog
  void _editProfile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch current user data
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .then((snapshot) {
      if (!mounted) return;
      final userData = snapshot.data();
      final nameCtrl = TextEditingController(
        text: userData?['name'] as String? ?? user.displayName ?? '',
      );
      final emailCtrl = TextEditingController(
        text: userData?['email'] as String? ?? user.email ?? '',
      );
      final phoneCtrl = TextEditingController(
        text: userData?['phone'] as String? ?? user.phoneNumber ?? '',
      );

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1A1A1A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '✏️ Edit Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              _editField('Full Name', nameCtrl, Icons.person_outline_rounded),
              const SizedBox(height: 12),
              _editField('Email', emailCtrl, Icons.email_outlined),
              const SizedBox(height: 12),
              _editField('Phone', phoneCtrl, Icons.phone_outlined),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                      'name': nameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D4F),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _editField(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF888888)),
        prefixIcon: Icon(icon, color: const Color(0xFF888888), size: 20),
        filled: true,
        fillColor: const Color(0xFF111111),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF272727)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF272727)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4D4F)),
        ),
      ),
    );
  }

  // 🚪 Logout Confirmation
  void _confirmLogout() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Are you sure you want to log out of your Multiverse account?',
          style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Color(0xFF888888),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final navigator = Navigator.of(context);
                await FirebaseAuth.instance.signOut();
                await _googleSignIn.signOut();

                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              } catch (e) {
                debugPrint("LOGOUT ERROR: $e");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'LOG OUT',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
