import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Rider Delivery Dashboard with Two Sections:
/// 1. Available Orders (status = "ready")
/// 2. My Orders (assignedRiderId == currentUserId)
class RiderDeliveryDashboard extends StatefulWidget {
  const RiderDeliveryDashboard({super.key});

  @override
  State<RiderDeliveryDashboard> createState() => _RiderDeliveryDashboardState();
}

class _RiderDeliveryDashboardState extends State<RiderDeliveryDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    final riderId = _auth.currentUser?.uid;

    if (riderId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: Text(
            'Please login to access this screen',
            style: TextStyle(color: Colors.white),
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
          'DELIVERY DASHBOARD',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF4D4F),
          labelColor: const Color(0xFFFF4D4F),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'AVAILABLE ORDERS', icon: Icon(Icons.list_alt)),
            Tab(text: 'MY ORDERS', icon: Icon(Icons.delivery_dining)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAvailableOrdersTab(),
          _buildMyOrdersTab(riderId),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 1: AVAILABLE ORDERS
  // Shows orders where status = "ready"
  // ==========================================
  Widget _buildAvailableOrdersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('orders')
          .where('status', isEqualTo: 'ready')
          .snapshots(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
          );
        }

        // Error state
        if (snapshot.hasError) {
          debugPrint('❌ [RiderDashboard] Error loading available orders: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading orders',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D4F),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final orders = snapshot.data?.docs ?? [];

        // Empty state
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 80,
                  color: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No orders available right now',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'New orders will appear here automatically',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        // Orders list
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data() as Map<String, dynamic>;
            return _buildAvailableOrderCard(order.id, data);
          },
        );
      },
    );
  }

  Widget _buildAvailableOrderCard(String orderId, Map<String, dynamic> data) {
    final customerName = data['customerName'] ?? data['address']?['name'] ?? 'Customer';
    final total = (data['total'] ?? data['totalAmount'] ?? 0).toDouble();
    final deliveryFee = (data['deliveryFee'] ?? 0).toDouble();
    final address = _formatAddress(data['address']);
    final shopName = data['shopName'] ?? 'Restaurant';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeAgo = _getTimeAgo(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${orderId.substring(0, 8)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'READY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Padding(padding: EdgeInsets.all(16)),

          // Restaurant & Customer Info
          _infoRow(Icons.store, 'Pickup from', shopName, const Color(0xFFFF4D4F)),
          const SizedBox(height: 12),
          _infoRow(Icons.person, 'Customer', customerName, Colors.blue),
          const SizedBox(height: 12),
          _infoRow(Icons.location_on, 'Deliver to', address, Colors.purple),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF333333), height: 1),
          const SizedBox(height: 12),

          // Pricing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Total',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Your Earning',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    '₹${deliveryFee.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Accept Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _acceptOrder(orderId),
              icon: const Icon(Icons.check_circle, size: 20),
              label: const Text(
                'ACCEPT ORDER',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D4F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 2: MY ORDERS
  // Shows orders where assignedRiderId == currentUserId
  // ==========================================
  Widget _buildMyOrdersTab(String riderId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('orders')
          .where('assignedRiderId', isEqualTo: riderId)
          .snapshots(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
          );
        }

        // Error state
        if (snapshot.hasError) {
          debugPrint('❌ [RiderDashboard] Error loading my orders: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading your orders',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D4F),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final orders = snapshot.data?.docs ?? [];

        // Empty state
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delivery_dining_outlined,
                  size: 80,
                  color: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No active deliveries',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Accept an order to start delivering',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        // Orders list
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data() as Map<String, dynamic>;
            return _buildMyOrderCard(order.id, data);
          },
        );
      },
    );
  }

  Widget _buildMyOrderCard(String orderId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'accepted';
    final customerName = data['customerName'] ?? data['address']?['name'] ?? 'Customer';
    final total = (data['total'] ?? data['totalAmount'] ?? 0).toDouble();
    final address = _formatAddress(data['address']);
    final shopName = data['shopName'] ?? 'Restaurant';
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeAgo = _getTimeAgo(updatedAt);

    // Get status info
    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusInfo.color.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusInfo.color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${orderId.substring(0, 8)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusInfo.color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusInfo.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Padding(padding: EdgeInsets.all(16)),

          // Order Info
          _infoRow(Icons.store, 'Pickup from', shopName, const Color(0xFFFF4D4F)),
          const SizedBox(height: 12),
          _infoRow(Icons.person, 'Customer', customerName, Colors.blue),
          const SizedBox(height: 12),
          _infoRow(Icons.location_on, 'Deliver to', address, Colors.purple),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF333333), height: 1),
          const SizedBox(height: 12),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Total',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Status Update Buttons
          _buildStatusButtons(orderId, status),
        ],
      ),
    );
  }

  Widget _buildStatusButtons(String orderId, String currentStatus) {
    // Define the status flow
    final statusFlow = [
      {'status': 'accepted', 'label': 'Waiting', 'icon': Icons.restaurant, 'color': const Color(0xFFFF4D4F)},
      {'status': 'picked', 'label': 'Picked Up', 'icon': Icons.shopping_bag, 'color': Colors.blue},
      {'status': 'on_the_way', 'label': 'On the Way', 'icon': Icons.directions_bike, 'color': Colors.purple},
      {'status': 'delivered', 'label': 'Delivered', 'icon': Icons.check_circle, 'color': Colors.green},
    ];

    // Find current status index
    final currentIndex = statusFlow.indexWhere((s) => s['status'] == currentStatus);

    // If already delivered, show completion message
    if (currentStatus == 'delivered') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
            SizedBox(height: 8),
            Text(
              'Order Delivered Successfully!',
              style: TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // Show next status button
    if (currentIndex >= 0 && currentIndex < statusFlow.length - 1) {
      final nextStatus = statusFlow[currentIndex + 1];
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(orderId, nextStatus['status'] as String),
          icon: Icon(nextStatus['icon'] as IconData, size: 20),
          label: Text(
            'Mark as ${nextStatus['label']}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: nextStatus['color'] as Color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  Future<void> _acceptOrder(String orderId) async {
    final riderId = _auth.currentUser?.uid;
    if (riderId == null) return;

    try {
      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
          ),
        );
      }

      // Update Firestore - THIS PREVENTS ORDER FROM DISAPPEARING
      await _firestore.collection('orders').doc(orderId).update({
        'assignedRiderId': riderId,
        'status': 'accepted', // Changed from 'ready' to 'accepted'
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Close loading
      if (mounted) {
        Navigator.pop(context);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Order accepted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Automatically switch to "My Orders" tab
        _tabController.animateTo(1);
      }

      debugPrint('✅ [RiderDashboard] Order $orderId accepted by rider $riderId');
    } catch (e) {
      // Close loading
      if (mounted) {
        Navigator.pop(context);
      }

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error accepting order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      debugPrint('❌ [RiderDashboard] Error accepting order: $e');
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      // Show loading
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
          ),
        );
      }

      // Update Firestore
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'picked') 'pickedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'on_the_way') 'onTheWayAt': FieldValue.serverTimestamp(),
        if (newStatus == 'delivered') 'deliveredAt': FieldValue.serverTimestamp(),
      });

      // Close loading
      if (mounted) {
        Navigator.pop(context);
      }

      // Show success message
      if (mounted) {
        final statusLabels = {
          'accepted': 'Waiting at Restaurant',
          'picked': 'Picked Up',
          'on_the_way': 'On the Way',
          'delivered': 'Delivered Successfully',
        };

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Status updated: ${statusLabels[newStatus]}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      debugPrint('✅ [RiderDashboard] Order $orderId status updated to: $newStatus');
    } catch (e) {
      // Close loading
      if (mounted) {
        Navigator.pop(context);
      }

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      debugPrint('❌ [RiderDashboard] Error updating status: $e');
    }
  }

  String _formatAddress(dynamic address) {
    if (address == null) return 'No address provided';
    if (address is String) return address;
    if (address is Map) {
      final parts = [
        address['house'],
        address['street'],
        address['area'],
        address['city'],
      ].where((e) => e != null && e.toString().isNotEmpty);
      return parts.join(', ');
    }
    return address.toString();
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return DateFormat('dd MMM, hh:mm a').format(dateTime);
  }

  ({String label, Color color, IconData icon}) _getStatusInfo(String status) {
    switch (status) {
      case 'accepted':
        return (label: 'WAITING', color: const Color(0xFFFF4D4F), icon: Icons.restaurant);
      case 'picked':
        return (label: 'PICKED', color: Colors.blue, icon: Icons.shopping_bag);
      case 'on_the_way':
        return (label: 'ON THE WAY', color: Colors.purple, icon: Icons.directions_bike);
      case 'delivered':
        return (label: 'DELIVERED', color: Colors.green, icon: Icons.check_circle);
      default:
        return (label: status.toUpperCase(), color: Colors.grey, icon: Icons.help);
    }
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
