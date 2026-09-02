import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class VendorEarningsScreen extends StatelessWidget {
  const VendorEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Login required'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEarningsOverview(user.uid),
          const SizedBox(height: 24),
          _buildPayoutHistory(user.uid),
        ],
      ),
    );
  }

  Widget _buildEarningsOverview(String vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId)
          .where('status', whereIn: ['completed', 'delivered'])
          .snapshots(),
      builder: (context, snapshot) {
        double totalEarnings = 0;
        double pendingPayout = 0;
        double commission = 0;
        int totalDeliveredOrders = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final amount = (data['total'] ?? data['totalAmount'] ?? 0)
                .toDouble();
            totalEarnings += amount;
            commission += amount * 0.05; // 5% platform commission
            totalDeliveredOrders++;
          }
          pendingPayout = totalEarnings - commission;
        }

        return Column(
          children: [
            // Total Revenue Card
            _earningCard(
              'Total Revenue',
              '₹${totalEarnings.toStringAsFixed(0)}',
              const Color(0xFF4CAF50),
              subtitle: 'From $totalDeliveredOrders delivered orders',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _earningCard(
                    'Net Earnings',
                    '₹${pendingPayout.toStringAsFixed(0)}',
                    const Color(0xFF2196F3),
                    subtitle: 'After 5% commission',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _earningCard(
                    'Platform Commission',
                    '₹${commission.toStringAsFixed(0)}',
                    const Color(0xFFFF5722),
                    subtitle: '5% per order',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _earningCard(
    String label,
    String value,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPayoutHistory(String vendorId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payout History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('payouts')
                .where('vendorId', isEqualTo: vendorId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text(
                  'No payouts yet',
                  style: TextStyle(color: Color(0xFFAAAAAA)),
                );
              }

              final payouts = snapshot.data!.docs;
              return Column(
                children: payouts.map((doc) {
                  final payout = doc.data();
                  final amount = (payout['amount'] ?? 0).toDouble();
                  final status = payout['status'] ?? 'pending';
                  final date =
                      (payout['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          status == 'completed'
                              ? Icons.check_circle
                              : Icons.pending,
                          color: status == 'completed'
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF9800),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹${amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormat('MMM dd, yyyy').format(date),
                                style: const TextStyle(
                                  color: Color(0xFFAAAAAA),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (status == 'completed'
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFFF9800))
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: status == 'completed'
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFFF9800),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
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
  }
}
