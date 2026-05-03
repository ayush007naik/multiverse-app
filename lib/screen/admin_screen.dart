import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../services/wallet_service.dart';
import '../services/product_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currencyFormatter =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to access this page')),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D0D),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFFF4D4F))),
          );
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final role = userData?['role'] as String? ?? 'user';

        if (role != 'admin') {
          return Scaffold(
            backgroundColor: const Color(0xFF0D0D0D),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'ACCESS DENIED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You do not have administrative privileges.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D0D0D),
            elevation: 0,
            title: const Text(
              'ADMIN DASHBOARD',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                onPressed: () => FirebaseAuth.instance.signOut(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: const Color(0xFFFF4D4F),
              tabs: const [
                Tab(text: 'OVERVIEW'),
                Tab(text: 'VENDORS'),
                Tab(text: 'RIDERS'),
                Tab(text: 'USERS'),
                Tab(text: 'PRODUCTS'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildVendorsTab(),
              _buildRidersTab(),
              _buildUsersTab(),
              _buildProductsTab(),
            ],
          ),
        );
      },
    );
  }

  // --- 1. OVERVIEW TAB (STATS ONLY) ---
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "App Performance",
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildMainStatsGrid(),
          const SizedBox(height: 24),
          _buildPayoutRequests(),
        ],
      ),
    );
  }

  Widget _buildMainStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _statStreamCard('Users', 'users', Icons.people, Colors.blue),
        _statStreamCard('Revenue', 'orders', Icons.payments, Colors.green),
        _statStreamCard('Commission', 'orders', Icons.account_balance_wallet, Colors.teal),
        _statStreamCard('Products', 'products', Icons.inventory_2, Colors.purple),
      ],
    );
  }

  Widget _statStreamCard(
      String label, String collection, IconData icon, Color color) {
    // For orders collection, calculate revenue and commission
    if (collection == 'orders') {
      return StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection(collection).snapshots(),
        builder: (context, snapshot) {
          final orders = snapshot.data?.docs ?? [];
          double totalRevenue = 0;
          double platformCommission = 0;
          
          for (var doc in orders) {
            final data = doc.data() as Map<String, dynamic>;
            totalRevenue += (data['total'] ?? data['totalAmount'] ?? 0).toDouble();
            platformCommission += (data['platformCommission'] ?? 
                                   data['commission'] ?? 
                                   data['adminCommission'] ?? 
                                   0).toDouble();
          }
          
          // Show revenue or commission based on label
          final value = label == 'Revenue' 
              ? currencyFormatter.format(totalRevenue)
              : currencyFormatter.format(platformCommission);
          
          return _baseStatCard(label, value, icon, color);
        },
      );
    }
    
    // For other collections, just show count
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection(collection).snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return _baseStatCard(label, count.toString(), icon, color);
      },
    );
  }

  Widget _baseStatCard(String label, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // --- 2. VENDOR MANAGEMENT ---
  Widget _buildVendorsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('shops').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final shops = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              "All Shops",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ...shops.map((s) => _approvedShopCard(s)),
          ],
        );
      },
    );
  }

  Widget _approvedShopCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isActive = data['isActive'] ?? true;
    final ownerId = data['ownerId'] ?? 'Unknown';
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
          child: const Icon(Icons.storefront, color: Color(0xFFFF4D4F), size: 18),
        ),
        title: Text(data['name'] ?? 'Shop',
            style: const TextStyle(color: Colors.white)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${data['category'] ?? 'Category'} • ${isActive ? "Live" : "Inactive"}',
              style: TextStyle(
                color: isActive ? Colors.green : Colors.grey,
                fontSize: 12,
              ),
            ),
            Text(
              'Owner: $ownerId',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
        trailing: Switch(
          value: isActive,
          activeColor: Colors.green,
          onChanged: (val) =>
              _firestore.collection('shops').doc(doc.id).update({'isActive': val}),
        ),
      ),
    );
  }

  // --- 3. RIDERS MANAGEMENT ---
  Widget _buildRidersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('role', isEqualTo: 'Delivery Partner')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final riders = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: riders.length,
          itemBuilder: (context, index) {
            final data = riders[index].data() as Map<String, dynamic>;
            final isActive = data['isEnabled'] ?? true;
            final isBlocked = data['isBlocked'] ?? false;
            final isOnline = data['isOnline'] ?? false;
            return Card(
              color: const Color(0xFF1E1E1E),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isOnline ? Colors.green : Colors.grey,
                  child: const Icon(Icons.delivery_dining, color: Colors.white),
                ),
                title: Text(data['name'] ?? 'Rider',
                    style: const TextStyle(color: Colors.white)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                            color: isOnline ? Colors.green : Colors.grey,
                            fontSize: 12)),
                    if (isBlocked)
                      const Text('BLOCKED',
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isBlocked ? Icons.lock : Icons.lock_open,
                        color: isBlocked ? Colors.red : Colors.green,
                      ),
                      onPressed: () => _firestore
                          .collection('users')
                          .doc(riders[index].id)
                          .update({'isBlocked': !isBlocked}),
                    ),
                    Switch(
                      value: isActive,
                      activeColor: Colors.green,
                      onChanged: (val) => _firestore
                          .collection('users')
                          .doc(riders[index].id)
                          .update({'isEnabled': val}),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 4. USERS MANAGEMENT ---
  Widget _buildUsersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('role', isEqualTo: 'Customer')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;
            final isBlocked = data['isBlocked'] ?? false;
            return Card(
              color: const Color(0xFF1E1E1E),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(data['name'] ?? 'User',
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(data['email'] ?? data['phone'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: ElevatedButton(
                  onPressed: () => _firestore
                      .collection('users')
                      .doc(users[index].id)
                      .update({'isBlocked': !isBlocked}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBlocked ? Colors.green : Colors.red,
                  ),
                  child: Text(isBlocked ? "UNBLOCK" : "BLOCK",
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 5. PRODUCTS VIEW ---
  Widget _buildProductsTab() {
    // STANDARDIZED: Using root 'products' collection instead of collectionGroup
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('products').snapshots(),
      builder: (context, snapshot) {
        // Handle loading state properly
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('⏳ [AdminScreen] Products loading...');
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D4F)));
        }

        // Handle errors with detailed logging
        if (snapshot.hasError) {
          print('❌ [AdminScreen] ERROR loading products:');
          print('   Error: ${snapshot.error}');
          print('   Stack Trace: ${snapshot.stackTrace}');
          
          // Check if it's a missing index error
          final isIndexError = ProductService.isMissingIndexError(snapshot.error);
          final indexUrl = ProductService.extractIndexCreationUrl(snapshot.error);
          
          if (isIndexError) {
            print('⚠️ [AdminScreen] MISSING INDEX ERROR DETECTED!');
            if (indexUrl != null) {
              print('🔗 [AdminScreen] Index Creation URL: $indexUrl');
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
            child: Padding(
              padding: const EdgeInsets.all(40.0),
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
            ),
          );
        }

        final products = snapshot.data?.docs ?? [];
        print('✅ [AdminScreen] Loaded ${products.length} products');
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final data = products[index].data() as Map<String, dynamic>;
            final shopId = data['shopId'] ?? '';
            final productId = products[index].id;
            return Container(
              decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                      child: data['imageUrl'] != null
                          ? Image.network(data['imageUrl'],
                              fit: BoxFit.cover, width: double.infinity)
                          : Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.image, color: Colors.grey)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['name'] ?? 'Product',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                            maxLines: 1),
                        Text('₹${data['price']}',
                            style: const TextStyle(
                                color: Color(0xFFFF4D4F), fontSize: 12)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(data['isAvailable'] == false ? 'HIDDEN' : 'LIVE',
                                style: TextStyle(
                                    color: data['isAvailable'] == false
                                        ? Colors.red
                                        : Colors.green,
                                    fontSize: 10)),
                            Transform.scale(
                              scale: 0.7,
                              child: Switch(
                                value: data['isAvailable'] ?? true,
                                onChanged: (val) => ProductService()
                                    .toggleProductStatus(shopId, productId, val),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- PAYOUT REQUESTS ---
  Widget _buildPayoutRequests() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Pending Payouts",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('payout_requests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              final reqs = snapshot.data?.docs ?? [];
              if (reqs.isEmpty)
                return const Text("No pending requests",
                    style: TextStyle(color: Colors.grey, fontSize: 12));
              return Column(
                children: reqs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('₹${data['amount']}',
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(data['vendorId'] ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            icon:
                                const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () => WalletService().updatePayoutStatus(
                                requestId: doc.id,
                                status: 'approved',
                                adminId: 'admin')),
                        IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => WalletService().updatePayoutStatus(
                                requestId: doc.id,
                                status: 'rejected',
                                adminId: 'admin')),
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
  }
}
