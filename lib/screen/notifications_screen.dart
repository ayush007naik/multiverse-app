import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/order_notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(child: Text('Please login to see notifications', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => OrderNotificationService().markAllAsRead(userId),
            child: const Text('Mark all as read', style: TextStyle(color: Color(0xFFFF4D4F))),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: OrderNotificationService().getUserNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D4F)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const _EmptyNotifications();
          }

          final notifications = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notification = notifications[index].data() as Map<String, dynamic>;
              final notificationId = notifications[index].id;
              final isRead = notification['read'] as bool? ?? false;
              final createdAt = notification['createdAt'] as Timestamp?;
              final dateStr = createdAt != null 
                  ? DateFormat('MMM d, h:mm a').format(createdAt.toDate())
                  : '';

              return InkWell(
                onTap: () {
                  OrderNotificationService().markAsRead(userId, notificationId);
                  // Optional: Navigate to order details if orderId is present
                  final orderId = notification['orderId'];
                  if (orderId != null) {
                    debugPrint('Tapped notification for order: $orderId');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRead ? const Color(0xFF1A1A1A) : const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRead ? Colors.transparent : const Color(0xFFFF4D4F).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIcon(notification['type'] as String?),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    notification['title'] ?? 'Notification',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFF4D4F),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification['message'] ?? '',
                              style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dateStr,
                              style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildIcon(String? type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'new_order':
        iconData = Icons.shopping_bag_outlined;
        iconColor = Colors.blue;
        break;
      case 'order_accepted':
        iconData = Icons.check_circle_outline;
        iconColor = Colors.green;
        break;
      case 'order_ready':
        iconData = Icons.inventory_2_outlined;
        iconColor = const Color(0xFFFF4D4F);
        break;
      case 'order_picked':
        iconData = Icons.delivery_dining_outlined;
        iconColor = Colors.purple;
        break;
      case 'order_delivered':
        iconData = Icons.celebration_outlined;
        iconColor = Colors.amber;
        break;
      default:
        iconData = Icons.notifications_outlined;
        iconColor = const Color(0xFFFF4D4F);
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, color: Color(0xFF555555), size: 64),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'We will notify you when something arrives.',
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
