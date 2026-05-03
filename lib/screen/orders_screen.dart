import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/invoice_generator_service.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('My Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: user == null
          ? const Center(child: Text('Please login to see orders', style: TextStyle(color: Colors.white)))
          : StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (ctx, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D4F)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildNoOrders();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (ctx, i) {
                    var order = snapshot.data!.docs[i];
                    return _buildOrderCard(ctx, order);
                  },
                );
              },
            ),
    );
  }

  Widget _buildNoOrders() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.receipt_long_outlined, size: 80, color: Color(0xFF333333)),
          SizedBox(height: 20),
          Text('No orders yet', style: TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, DocumentSnapshot order) {
    var data = order.data() as Map<String, dynamic>;
    var date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    var status = data['status'] ?? 'new';
    var items = data['items'] as List;

    Color statusColor;
    switch (status) {
      case 'preparing':
        statusColor = const Color(0xFFFF4D4F);
        break;
      case 'ready':
        statusColor = Colors.blue;
        break;
      case 'delivered':
        statusColor = Colors.green;
        break;
      default:
        statusColor = const Color(0xFFFF4D4F);
    }

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${order.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(data['shopName'] ?? 'Shop', style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(DateFormat('dd MMM yyyy, hh:mm a').format(date),
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const Divider(color: Color(0xFF272727), height: 24),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item['qty'] ?? item['quantity']}x ${item['name']}', style: const TextStyle(color: Colors.white70)),
                    Text('₹${item['price']}', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              )),
          const Divider(color: Color(0xFF272727), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('₹${data['total'] ?? data['totalAmount']}',
                  style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          if (status == 'delivered') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showInvoiceOptions(context, order.id),
                icon: const Icon(Icons.receipt_long, color: Color(0xFFFF4D4F)),
                label: const Text('Invoice', style: TextStyle(color: Color(0xFFFF4D4F))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF4D4F)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showInvoiceOptions(BuildContext context, String orderId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Invoice Options', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              ListTile(
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await InvoiceGeneratorService.generateInvoicePdf(orderId);
                },
                leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFFF4D4F)),
                title: const Text('Download PDF', style: TextStyle(color: Colors.white)),
                tileColor: const Color(0xFF272727),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(height: 8),
              ListTile(
                onTap: () {
                  Navigator.of(ctx).pop();
                  // TODO: Implement email invoice feature
                },
                leading: const Icon(Icons.email, color: Color(0xFFFF4D4F)),
                title: const Text('Email Invoice', style: TextStyle(color: Colors.white)),
                tileColor: const Color(0xFF272727),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFFFF4D4F))),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
