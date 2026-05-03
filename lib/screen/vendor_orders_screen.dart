import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../models/order_model.dart';

/// Vendor Order Management Screen
/// Listens to orders in real-time and allows status updates:
/// pending → confirmed → preparing → ready
class VendorOrdersScreen extends StatefulWidget {
  final String shopId;
  
  const VendorOrdersScreen({super.key, required this.shopId});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text(
          'Order Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: orderProvider.streamVendorActiveOrders(widget.shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final orders = snapshot.data?.docs ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No orders yet',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final orderDoc = orders[index];
              final order = OrderModel.fromFirestore(
                orderDoc.data(),
                orderDoc.id,
              );

              return _buildOrderCard(order, orderProvider);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, OrderProvider orderProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(OrderModel.getStatusColor(order.status)),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${order.id.substring(0, 8)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Color(OrderModel.getStatusColor(order.status))
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  OrderModel.getStatusText(order.status),
                  style: TextStyle(
                    color: Color(OrderModel.getStatusColor(order.status)),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Customer Info
          if (order.customerName != null || order.customerPhone != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.customerName != null)
                  Text(
                    'Customer: ${order.customerName}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                if (order.customerPhone != null)
                  Text(
                    'Phone: ${order.customerPhone}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                const SizedBox(height: 8),
              ],
            ),

          // Items
          const Text(
            'Items:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${item['name']} x${item['qty']} - ₹${item['price'] * item['qty']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              )),
          const Divider(color: Color(0xFF333333), height: 24),

          // Order Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFFF4D4F),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons based on status
          _buildActionButtons(order, orderProvider),
        ],
      ),
    );
  }

  Widget _buildActionButtons(OrderModel order, OrderProvider orderProvider) {
    return Wrap(
      spacing: 8,
      children: [
        // Accept Button (pending → accepted)
        if (order.canAccept())
          ElevatedButton.icon(
            onPressed: () => _acceptOrder(order.id, orderProvider),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Accept'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
          ),

        // Start Preparing (accepted → preparing)
        if (order.canStartPreparing())
          ElevatedButton.icon(
            onPressed: () => _startPreparing(order.id, orderProvider),
            icon: const Icon(Icons.restaurant, size: 18),
            label: const Text('Start Preparing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4F),
              foregroundColor: Colors.white,
            ),
          ),

        // Mark Ready (preparing → ready)
        if (order.canMarkReady())
          ElevatedButton.icon(
            onPressed: () => _markReady(order.id, orderProvider),
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('Mark Ready'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Future<void> _acceptOrder(String orderId, OrderProvider orderProvider) async {
    try {
      await orderProvider.acceptOrder(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startPreparing(String orderId, OrderProvider orderProvider) async {
    try {
      await orderProvider.startPreparingOrder(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing order'),
            backgroundColor: Color(0xFFFF4D4F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markReady(String orderId, OrderProvider orderProvider) async {
    try {
      await orderProvider.markOrderReady(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order ready for pickup'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
