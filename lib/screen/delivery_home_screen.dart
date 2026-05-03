import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/logout_service.dart';
import '../services/wallet_service.dart';
import '../services/invoice_generator_service.dart';
import '../providers/order_provider.dart';
import '../utils/delivery_fee_calculator.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'delivery_complete_screen.dart';
import 'wallet_screen.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<Position>? _liveTrackingStream;
  bool _isOnline = false;
  String _vehicle = DeliveryFeeCalculator.bikeVehicle;
  late TabController _tabController;
  String? _currentActiveOrderId; // Track active order for live tracking

  @override
  void initState() {
    super.initState();
    _loadRiderVehicle();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _liveTrackingStream?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _toggleOnline(bool status) async {
    setState(() => _isOnline = status);
    await _setAvailability(status);

    if (status) {
      // Start general location tracking
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((Position position) {
            _updateRiderLocation(position);
            
            // If on the way, also update order location
            if (_currentActiveOrderId != null) {
              _updateOrderLocation(_currentActiveOrderId!, position);
            }
          });
    } else {
      _positionStream?.cancel();
      _liveTrackingStream?.cancel();
    }
  }

  Future<void> _setAvailability(bool isAvailable) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('delivery_locations')
        .doc(user.uid)
        .set({
          'riderId': user.uid,
          'name': user.displayName ?? 'Delivery Partner',
          'phone': user.phoneNumber ?? '',
          'vehicle': _vehicle,
          'isAvailable': isAvailable,
          'lastUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _loadRiderVehicle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final vehicle = data?['vehicleType'] ?? data?['vehicle'];
      if (!mounted) return;
      setState(() {
        _vehicle = _normalizeVehicle(vehicle);
      });
    } catch (e) {
      debugPrint('Error loading rider vehicle: $e');
    }
  }

  void _updateRiderLocation(Position pos) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('delivery_locations')
          .doc(user.uid)
          .set({
            'riderId': user.uid,
            'name': user.displayName ?? 'Delivery Partner',
            'phone': user.phoneNumber ?? '',
            'vehicle': _vehicle,
            'lat': pos.latitude,
            'lng': pos.longitude,
            'isAvailable': _isOnline,
            'lastUpdate': FieldValue.serverTimestamp(),
            'accuracy': pos.accuracy,
            'heading': pos.heading,
            'speed': pos.speed,
          }, SetOptions(merge: true));
    }
  }

  /// Update order document with rider's live location
  /// Called when status = "on_the_way"
  void _updateOrderLocation(String orderId, Position pos) {
    FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({
      'riderLat': pos.latitude,
      'riderLng': pos.longitude,
      'riderLocationUpdated': FieldValue.serverTimestamp(),
    }).catchError((e) {
      debugPrint('❌ Error updating order location: $e');
    });
  }

  /// Start live tracking for specific order
  void _startLiveTracking(String orderId) {
    debugPrint('📍 [DeliveryHome] Starting live tracking for order: $orderId');
    _currentActiveOrderId = orderId;

    // Cancel any existing tracking
    _liveTrackingStream?.cancel();

    // Start high-frequency location updates for active delivery
    _liveTrackingStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((Position position) {
      _updateOrderLocation(orderId, position);
      debugPrint(
        '📍 Location updated: ${position.latitude}, ${position.longitude}',
      );
    });
  }

  /// Stop live tracking
  void _stopLiveTracking() {
    debugPrint('🛑 [DeliveryHome] Stopping live tracking');
    _liveTrackingStream?.cancel();
    _liveTrackingStream = null;
    _currentActiveOrderId = null;
  }

  void _updateStatus(String id, String status) async {
    final user = FirebaseAuth.instance.currentUser;
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    try {
      if (status == 'picked') {
        if (user != null) {
          await orderProvider.pickOrder(id, user.uid);

          // Mark as unavailable when assigned
          await FirebaseFirestore.instance
              .collection('delivery_locations')
              .doc(user.uid)
              .set({
            'isAvailable': false,
            'lastUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else if (status == 'delivered') {
        await orderProvider.deliverOrder(id);

        if (user != null) {
          // Mark as available again when delivered
          await FirebaseFirestore.instance
              .collection('delivery_locations')
              .doc(user.uid)
              .set({
            'isAvailable': _isOnline, // Use current toggle status
            'assignedOrderId': FieldValue.delete(),
            'lastUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        // Generate Invoice
        try {
          await InvoiceGeneratorService.generateAndSaveInvoice(id);
        } catch (e) {
          debugPrint('Error generating invoice: $e');
        }

        // Navigate to delivery complete screen
        final orderDoc = await FirebaseFirestore.instance.collection('orders').doc(id).get();
        if (orderDoc.exists && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DeliveryCompleteScreen(
                orderId: id,
                orderData: orderDoc.data()!,
              ),
            ),
          );
          return; // Exit early to avoid showing snackbar
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'picked'
                ? 'Order Accepted!'
                : 'Order Delivered! Great job.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
  }

  // ========================================
  // TAB 1: AVAILABLE ORDERS
  // Shows orders where status = 'ready'
  // ========================================
  Widget _buildAvailableOrdersTab() {
    final user = FirebaseAuth.instance.currentUser;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
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
          debugPrint('❌ [DeliveryHome] Error loading available orders: ${snapshot.error}');
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
                    icon: const Icon(Icons.refresh, size: 18),
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
                  color: Colors.grey.withValues(alpha: 0.3),
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
            return _buildAvailableOrderCard(order.id, data, user?.uid);
          },
        );
      },
    );
  }

  Widget _buildAvailableOrderCard(String orderId, Map<String, dynamic> data, String? riderId) {
    final customerName = data['customerName'] ?? data['address']?['name'] ?? 'Customer';
    final total = (data['total'] ?? data['totalAmount'] ?? 0).toDouble();
    final deliveryFee = (data['deliveryFee'] ?? 0).toDouble();
    final address = _formatAddress(data['address']);
    final shopName = data['shopName'] ?? data['restaurantName'] ?? 'Restaurant';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
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
                      const Text(
                        'Ready for pickup',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
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

          // Order Info
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
              onPressed: riderId != null ? () => _acceptOrder(orderId, riderId) : null,
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

  // ========================================
  // TAB 2: MY ORDERS
  // Shows orders where assignedRiderId == currentUserId
  // ========================================
  Widget _buildMyOrdersTab() {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return const Center(
        child: Text('Please login', style: TextStyle(color: Colors.white)),
      );
    }

    debugPrint('📦 [MyOrders] Loading orders for rider: ${user.uid}');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('assignedRiderId', isEqualTo: user.uid)
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
          debugPrint('❌ [DeliveryHome] Error loading my orders: ${snapshot.error}');
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
        debugPrint('📦 [MyOrders] Found ${orders.length} orders');

        // Empty state
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delivery_dining_outlined,
                  size: 80,
                  color: Colors.grey.withValues(alpha: 0.3),
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
            final status = data['status'] ?? 'unknown';
            debugPrint('📦 [MyOrders] Order ${order.id}: status = $status');
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
    final shopName = data['shopName'] ?? data['restaurantName'] ?? 'Restaurant';

    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusInfo.color.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusInfo.color.withValues(alpha: 0.1),
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
                        statusInfo.label,
                        style: TextStyle(color: statusInfo.color, fontSize: 12),
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
                    statusInfo.shortLabel,
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
    debugPrint('🔘 [StatusButtons] Order: $orderId, Current Status: $currentStatus');
    
    // Define the status flow with correct labels
    final statusFlow = [
      {'status': 'accepted', 'label': 'Picked Up', 'icon': Icons.shopping_bag, 'color': Colors.blue},
      {'status': 'picked', 'label': 'On the Way', 'icon': Icons.directions_bike, 'color': Colors.purple},
      {'status': 'on_the_way', 'label': 'Delivered', 'icon': Icons.check_circle, 'color': Colors.green},
    ];

    // If already delivered, show completion message
    if (currentStatus == 'delivered') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
            SizedBox(height: 8),
            Text(
              '✅ Order Delivered Successfully!',
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

    // Find current status index and show next button
    final currentIndex = statusFlow.indexWhere((s) => s['status'] == currentStatus);
    
    debugPrint('🔘 [StatusButtons] Current Index: $currentIndex');

    if (currentIndex >= 0 && currentIndex < statusFlow.length) {
      final nextStatus = statusFlow[currentIndex];
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            debugPrint('🔘 [BUTTON CLICKED] ==========');
            debugPrint('🔘 [BUTTON CLICKED] Order ID: $orderId');
            debugPrint('🔘 [BUTTON CLICKED] Current Status: $currentStatus');
            debugPrint('🔘 [BUTTON CLICKED] Next Status: ${nextStatus['label']}');
            debugPrint('🔘 [BUTTON CLICKED] Calling _updateOrderStatusWithTracking...');
            _updateOrderStatusWithTracking(
              orderId, 
              nextStatus['status'] as String, 
              currentStatus
            );
          },
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

    // If status is not in flow (e.g., 'ready'), show appropriate message
    debugPrint('⚠️ [StatusButtons] Status not in flow: $currentStatus');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Status: $currentStatus\nAccept this order from Available Orders tab',
        style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ========================================
  // HELPER METHODS
  // ========================================

  Future<void> _acceptOrder(String orderId, String riderId) async {
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
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'assignedRiderId': riderId,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Close loading
      if (mounted) {
        Navigator.pop(context);
      }

      // Show success and switch to My Orders tab
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Order accepted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Switch to My Orders tab
        _tabController.animateTo(1);
      }

      debugPrint('✅ [DeliveryHome] Order $orderId accepted by rider $riderId');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('❌ [DeliveryHome] Error accepting order: $e');
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
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
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

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Status updated!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      debugPrint('✅ [DeliveryHome] Order $orderId status: $newStatus');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('❌ [DeliveryHome] Error updating status: $e');
    }
  }

  /// Enhanced status update with live tracking integration
  Future<void> _updateOrderStatusWithTracking(
    String orderId,
    String newStatus,
    String currentStatus,
  ) async {
    debugPrint('🔴 [STATUS UPDATE] ========== START ==========');
    debugPrint('🔴 [STATUS UPDATE] Order ID: $orderId');
    debugPrint('🔴 [STATUS UPDATE] Current Status: $currentStatus');
    debugPrint('🔴 [STATUS UPDATE] New Status: $newStatus');
    
    try {
      // Verify order exists before updating
      debugPrint('🔵 [STATUS UPDATE] Checking if order exists...');
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      
      if (!orderDoc.exists) {
        debugPrint('❌ [STATUS UPDATE] Order does NOT exist!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Order not found in Firestore!'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final currentData = orderDoc.data()!;
      debugPrint('🔵 [STATUS UPDATE] Order found! Current data:');
      debugPrint('   - status: ${currentData['status']}');
      debugPrint('   - assignedRiderId: ${currentData['assignedRiderId']}');
      
      // Show loading
      if (mounted) {
        debugPrint('🔵 [STATUS UPDATE] Showing loading dialog...');
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
          ),
        );
      }

      // Prepare update data
      final updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (newStatus == 'picked') {
        updateData['pickedAt'] = FieldValue.serverTimestamp();
      }
      if (newStatus == 'on_the_way') {
        updateData['onTheWayAt'] = FieldValue.serverTimestamp();
      }
      if (newStatus == 'delivered') {
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
      }
      
      debugPrint('🔵 [STATUS UPDATE] Update data: $updateData');
      debugPrint('🔵 [STATUS UPDATE] Updating Firestore...');

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(updateData);
      
      debugPrint('✅ [STATUS UPDATE] Firestore update SUCCESS!');

      // Verify the update
      debugPrint('🔵 [STATUS UPDATE] Verifying update...');
      final updatedDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      
      if (updatedDoc.exists) {
        final updatedData = updatedDoc.data()!;
        debugPrint('✅ [STATUS UPDATE] Verified! New status: ${updatedData['status']}');
      } else {
        debugPrint('⚠️ [STATUS UPDATE] Warning: Order not found after update!');
      }

      // Start live tracking when status becomes "on_the_way"
      if (newStatus == 'on_the_way') {
        _startLiveTracking(orderId);
        debugPrint('📍 [STATUS UPDATE] Live tracking started for order: $orderId');
      }

      // Stop live tracking and handle delivery completion
      if (newStatus == 'delivered') {
        _stopLiveTracking();
        debugPrint('🛑 [STATUS UPDATE] Live tracking stopped');
        
        // Generate Invoice
        try {
          debugPrint('🔵 [STATUS UPDATE] Generating invoice...');
          await InvoiceGeneratorService.generateAndSaveInvoice(orderId);
          debugPrint('✅ [STATUS UPDATE] Invoice generated');
        } catch (e) {
          debugPrint('⚠️ [STATUS UPDATE] Error generating invoice: $e');
        }

        // Navigate to delivery complete screen
        if (mounted) {
          debugPrint('🔵 [STATUS UPDATE] Fetching order for completion screen...');
          final orderDoc = await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .get();
          
          if (orderDoc.exists) {
            debugPrint('✅ [STATUS UPDATE] Navigating to completion screen...');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DeliveryCompleteScreen(
                  orderId: orderId,
                  orderData: orderDoc.data()!,
                ),
              ),
            );
            Navigator.pop(context); // Close loading dialog
            debugPrint('🔴 [STATUS UPDATE] ========== COMPLETE (NAVIGATED) ==========');
            return;
          }
        }
      }

      // Close loading
      if (mounted) {
        debugPrint('🔵 [STATUS UPDATE] Closing loading dialog...');
        Navigator.pop(context);
      }

      // Show success message
      if (mounted) {
        final statusMessages = {
          'accepted': '✅ Order accepted!',
          'picked': '✅ Order picked up!',
          'on_the_way': '📍 Live tracking started - On the way!',
          'delivered': '✅ Order delivered successfully!',
        };

        debugPrint('🔵 [STATUS UPDATE] Showing success message...');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(statusMessages[newStatus] ?? '✅ Status updated!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      debugPrint('✅ [STATUS UPDATE] Order $orderId: $currentStatus → $newStatus');
      debugPrint('🔴 [STATUS UPDATE] ========== END (SUCCESS) ==========');
    } catch (e, stackTrace) {
      debugPrint('❌ [STATUS UPDATE] ========== ERROR ==========');
      debugPrint('❌ [STATUS UPDATE] Error: $e');
      debugPrint('❌ [STATUS UPDATE] Stack trace: $stackTrace');
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('🔴 [STATUS UPDATE] ========== END (ERROR) ==========');
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

  ({String label, String shortLabel, Color color}) _getStatusInfo(String status) {
    switch (status) {
      case 'accepted':
        return (label: 'Waiting at Restaurant', shortLabel: 'WAITING', color: const Color(0xFFFF4D4F));
      case 'picked':
        return (label: 'Picked Up', shortLabel: 'PICKED', color: Colors.blue);
      case 'on_the_way':
        return (label: 'On the Way', shortLabel: 'ON THE WAY', color: Colors.purple);
      case 'delivered':
        return (label: 'Delivered', shortLabel: 'DELIVERED', color: Colors.green);
      default:
        return (label: status, shortLabel: status.toUpperCase(), color: Colors.grey);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo.png'),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MULTIVERSE Rider',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openMap,
            icon: const Icon(Icons.map_outlined, color: Color(0xFFFF4D4F)),
          ),
          Switch(
            value: _isOnline,
            onChanged: _toggleOnline,
            activeColor: Colors.green,
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _showLogoutConfirmation,
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuickStats(),
          // TabBar
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFFF4D4F),
            labelColor: const Color(0xFFFF4D4F),
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'AVAILABLE ORDERS', icon: Icon(Icons.list_alt)),
              Tab(text: 'MY ORDERS', icon: Icon(Icons.delivery_dining)),
            ],
          ),
          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAvailableOrdersTab(),
                _buildMyOrdersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
              _positionStream?.cancel();
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

  Future<void> _updateRiderDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        final TextEditingController vehicleController = TextEditingController(text: _vehicle);
        final TextEditingController numberController = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Rider Details', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vehicleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type (bike/car)',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              TextField(
                controller: numberController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Vehicle Number',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, {
                'vehicle': vehicleController.text,
                'number': numberController.text,
              }),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final normalized = _normalizeVehicle(result['vehicle']);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'vehicle': normalized,
        'vehicleNumber': result['number'],
      });
      setState(() {
        _vehicle = normalized;
      });
    }
  }

  Widget _buildQuickStats() {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: user == null
                      ? const Stream.empty()
                      : WalletService().walletRef(user.uid).snapshots(),
                  builder: (context, snapshot) {
                    double balance = 0.0;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      balance = (snapshot.data!.data() as Map<String, dynamic>)['balance']?.toDouble() ?? 0.0;
                    }
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
                      child: _statItem(
                        'Wallet Balance',
                        '₹${balance.toStringAsFixed(0)}',
                        Colors.green,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: user == null
                      ? const Stream.empty()
                      : FirebaseFirestore.instance
                            .collection('orders')
                            .where('riderId', isEqualTo: user.uid)
                            .where('status', isEqualTo: 'delivered')
                            .snapshots(),
                  builder: (context, snapshot) {
                    // Handle errors gracefully
                    if (snapshot.hasError) {
                      debugPrint('⚠️ [DeliveryHome] Error loading deliveries count: ${snapshot.error}');
                      return _statItem(
                        'Deliveries',
                        '0',
                        Colors.blue,
                      );
                    }
                    
                    return _statItem(
                      'Deliveries',
                      '${snapshot.data?.docs.length ?? 0}',
                      Colors.blue,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _updateRiderDetails,
            child: _statItem(
              'Vehicle & Info (Tap to edit)',
              DeliveryFeeCalculator.formatVehicle(_vehicle),
              const Color(0xFFFF4D4F),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCompatibleOrder(DocumentSnapshot order) {
    final data = order.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'ready';
    final user = FirebaseAuth.instance.currentUser;

    if (status == 'picked') {
      return data['riderId'] == user?.uid;
    }

    final assignedRiderId = data['riderId'] as String?;
    if (assignedRiderId != null && assignedRiderId.isNotEmpty) {
      return assignedRiderId == user?.uid;
    }

    final orderVehicle = _normalizeVehicle(data['vehicle']);
    return orderVehicle == _vehicle;
  }

  String _normalizeVehicle(dynamic vehicle) {
    final value = vehicle?.toString().toLowerCase().trim() ?? '';
    if (value == DeliveryFeeCalculator.carVehicle ||
        value == 'four-wheeler' ||
        value == 'four_wheeler' ||
        value == '4-wheeler' ||
        value == 'car' ||
        value == 'van') {
      return DeliveryFeeCalculator.carVehicle;
    }
    return DeliveryFeeCalculator.bikeVehicle;
  }

  Widget _statItem(String label, String val, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 5),
          Text(
            val,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delivery_dining_outlined,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'No orders available right now',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(DocumentSnapshot order) {
    var data = order.data() as Map<String, dynamic>;
    String status = data['status'] ?? 'ready';
    bool isPicked = status == 'picked';
    final vehicle = _normalizeVehicle(data['vehicle']);
    final deliveryType = DeliveryFeeCalculator.normalizeDeliveryType(
      data['deliveryType'] as String?,
    );

    String customer = data['customer'] ?? 'Customer';
    String address = 'No Address';
    if (data['address'] != null) {
      if (data['address'] is Map) {
        customer = data['address']['name'] ?? customer;
        address = data['address']['address'] ?? 'Mandi';
      } else {
        address = data['address'].toString();
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPicked ? const Color(0xFFFF4D4F).withValues(alpha: 0.3) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order.id.substring(0, 5)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPicked
                      ? const Color(0xFFFF4D4F).withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: isPicked ? const Color(0xFFFF4D4F) : Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _addressRow(
            Icons.storefront,
            'Pickup',
            'Mandi Bazaar (Sharma Hardware)',
          ),
          const SizedBox(height: 10),
          _addressRow(Icons.location_on, 'Drop to $customer', address),
          const SizedBox(height: 10),
          _addressRow(
            Icons.local_shipping_outlined,
            DeliveryFeeCalculator.formatDeliveryType(deliveryType),
            DeliveryFeeCalculator.formatVehicle(vehicle),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  _updateStatus(order.id, isPicked ? 'delivered' : 'picked'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPicked ? Colors.green : const Color(0xFFFF4D4F),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isPicked ? 'Mark Delivered' : 'Accept & Pickup',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressRow(IconData icon, String label, String address) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
            Text(
              address,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
