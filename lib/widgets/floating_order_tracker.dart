// Floating Live Order Tracking Widget for Home Screen
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screen/order_tracking_screen.dart';

class FloatingOrderTracker extends StatefulWidget {
  const FloatingOrderTracker({super.key});
  @override
  State<FloatingOrderTracker> createState() => _FloatingOrderTrackerState();
}

class _FloatingOrderTrackerState extends State<FloatingOrderTracker> {
  List<Map<String, dynamic>> _activeOrders = [];
  StreamSubscription? _ordersSubscription;
  StreamSubscription? _returnsSubscription;

  @override
  void initState() {
    super.initState();
    _listenToOrders();
    _listenToReturns();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _returnsSubscription?.cancel();
    super.dispose();
  }

  void _listenToOrders() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _ordersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['pending', 'placed', 'assigned', 'accepted', 'preparing', 'ready', 'picked', 'on_the_way', 'out_for_delivery'])
        .snapshots()
        .listen((snapshot) async {
      _handleSnapshot(snapshot, isReturn: false);
    });
  }

  void _listenToReturns() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _returnsSubscription = FirebaseFirestore.instance
        .collection('return_requests')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: [
          'pickup_scheduled', 
          'pickup_in_transit', 
          'reached_pickup', 
          'picked', 
          'reached_shop', 
          'out_for_delivery', 
          'shop_to_customer_transit'
        ])
        .snapshots()
        .listen((snapshot) {
      _handleSnapshot(snapshot, isReturn: true);
    });
  }

  void _handleSnapshot(QuerySnapshot snapshot, {required bool isReturn}) async {
    if (!mounted) return;

    final newOrders = await Future.wait(snapshot.docs.map((doc) async {
      final data = doc.data();
      data['id'] = doc.id;
      data['isReturnTracking'] = isReturn;
      
      if (isReturn) {
        data['trackingId'] = doc.id;
        String statusText = 'Tracking Return';
        switch (data['status']) {
          case 'pickup_scheduled': statusText = 'Pickup Scheduled'; break;
          case 'pickup_in_transit': statusText = 'Rider is coming to you'; break;
          case 'reached_pickup': statusText = 'Rider has arrived'; break;
          case 'picked': statusText = 'Item collected'; break;
          case 'reached_shop': statusText = 'Arrived at Shop'; break;
          case 'out_for_delivery': 
          case 'shop_to_customer_transit': statusText = 'Return in transit'; break;
        }
        data['displayStatus'] = statusText;
        data['displayTitle'] = 'Return Request: ${data['shopName'] ?? 'Order'}';
      } else {
        if (data['shopId'] != null && data['shopName'] == null) {
          try {
            final shopDoc = await FirebaseFirestore.instance.collection('shops').doc(data['shopId']).get();
            data['shopName'] = shopDoc.data()?['name'] ?? 'Store';
          } catch (_) { data['shopName'] = 'Store'; }
        }
        data['displayTitle'] = data['shopName'] ?? 'Track Order';
        data['displayStatus'] = _getOrderStatusText(data['status']);
      }
      return data;
    }).toList());

    if (mounted) {
      setState(() {
        // Filter out old versions of the same order/return if they exist
        final Map<String, Map<String, dynamic>> combined = {};
        
        // Add existing ones that aren't from this source type
        for (var o in _activeOrders) {
          if (o['isReturnTracking'] != isReturn) {
            combined[o['id']] = o;
          }
        }
        
        // Add new ones
        for (var o in newOrders) {
          combined[o['id']] = o;
        }
        
        _activeOrders = combined.values.toList();
        // Sort by some criteria if needed, e.g., most recent
      });
    }
  }

  String _getOrderStatusText(String? status) {
    switch (status) {
      case 'pending':
      case 'placed': return 'Order Placed';
      case 'assigned':
      case 'accepted': return 'Order Accepted';
      case 'preparing': return 'Preparing Order';
      case 'ready': return 'Ready for Pickup';
      case 'picked':
      case 'on_the_way':
      case 'out_for_delivery': return 'On the way';
      default: return 'Tracking...';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeOrders.isEmpty) return const SizedBox.shrink();
    final order = _activeOrders.first;
    final isReturn = order['isReturnTracking'] == true;

    return Positioned(
      bottom: 120, left: 16, right: 16,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(
              orderId: isReturn ? (order['orderId'] ?? order['id']) : order['id'],
              returnRequestId: isReturn ? order['id'] : null,
            )
          )
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF14141C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isReturn ? Colors.blue : const Color(0xFFFF6A00)),
            boxShadow: [
              BoxShadow(
                color: (isReturn ? Colors.blue : const Color(0xFFFF6A00)).withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            children: [
              Icon(
                isReturn ? Icons.assignment_return : Icons.delivery_dining, 
                color: isReturn ? Colors.blue : const Color(0xFFFF6A00)
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      order['displayTitle'] ?? 'Track Order', 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                    Text(
                      order['displayStatus'] ?? '', 
                      style: TextStyle(color: (isReturn ? Colors.blue : const Color(0xFFFF6A00)).withValues(alpha: 0.8), fontSize: 12)
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    );
  }

}
