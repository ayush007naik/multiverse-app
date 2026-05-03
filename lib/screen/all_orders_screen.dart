import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AllOrdersScreen extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const AllOrdersScreen({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'All Orders',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final o = orders[index];
          return _buildOrderCard(o);
        },
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF272727)),
      ),
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
}
