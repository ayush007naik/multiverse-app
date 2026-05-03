import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';

class VendorScreen extends StatelessWidget {
  const VendorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // For demo, assuming this vendor manages 'shop_1'
    // In real app, you'd fetch vendor's shopId from their user profile
    const String myShopId = 's1';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('Vendor Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder(
        stream: context.read<OrderProvider>().streamShopOrders(myShopId),
        builder: (ctx, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D4F)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }

          final orders = snapshot.data?.docs ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Text('No orders yet', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (ctx, i) {
              var order = orders[i];
              return _buildVendorOrderCard(context, order);
            },
          );
        },
      ),
    );
  }

  Widget _buildVendorOrderCard(BuildContext context, DocumentSnapshot order) {
    var data = order.data() as Map<String, dynamic>;
    var status = data['status'] ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order #${order.id.substring(0, 6)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 12),
          ...(data['items'] as List<dynamic>).map((item) => Text('• ${item['name']} x ${item['quantity']}', style: const TextStyle(color: Colors.grey))).toList(),
          const Divider(color: Color(0xFF333333), height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateStatus(order.id, 'preparing'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D4F).withValues(alpha: 0.2)),
                  child: const Text('Accept & Prepare', style: TextStyle(color: Color(0xFFFF4D4F), fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateStatus(order.id, 'ready'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.2)),
                  child: const Text('Mark Ready', style: TextStyle(color: Colors.green, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateStatus(String id, String status) {
    FirebaseFirestore.instance.collection('orders').doc(id).update({'status': status});
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFFF4D4F).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}