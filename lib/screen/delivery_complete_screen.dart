import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rating_screen.dart';
import 'delivery_home_screen.dart';

class DeliveryCompleteScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const DeliveryCompleteScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<DeliveryCompleteScreen> createState() => _DeliveryCompleteScreenState();
}

class _DeliveryCompleteScreenState extends State<DeliveryCompleteScreen> {
  bool _isRatingSubmitted = false;

  @override
  void initState() {
    super.initState();
    _checkIfRatingSubmitted();
  }

  Future<void> _checkIfRatingSubmitted() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ratingQuery = await FirebaseFirestore.instance
          .collection('ratings')
          .where('orderId', isEqualTo: widget.orderId)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _isRatingSubmitted = ratingQuery.docs.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error checking rating status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.orderData['address']?['name'] ?? 'Customer';
    final totalAmount = widget.orderData['total'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
              ),

              const SizedBox(height: 30),

              // Success Message
              const Text(
                'Delivery Completed!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              Text(
                'Order #${widget.orderId.substring(0, 6).toUpperCase()} delivered successfully',
                style: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Order Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF272727)),
                ),
                child: Column(
                  children: [
                    _detailRow('Customer', customerName),
                    const SizedBox(height: 12),
                    _detailRow('Amount Collected', '₹$totalAmount'),
                    const SizedBox(height: 12),
                    _detailRow('Delivery Time', _getDeliveryTime()),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Rating Section
              if (!_isRatingSubmitted) ...[
                const Text(
                  'Rate this delivery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _showRatingScreen,
                  icon: const Icon(Icons.star, color: Colors.white),
                  label: const Text('Rate Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D4F),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 10),
                      Text(
                        'Rating Submitted',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeliveryHomeScreen(),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF4D4F)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Back to Home',
                        style: TextStyle(
                          color: Color(0xFFFF4D4F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeliveryHomeScreen(),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D4F),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Accept More Orders',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFAAAAAA),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _getDeliveryTime() {
    final deliveredAt = widget.orderData['deliveredAt'];
    if (deliveredAt == null) return 'Just now';

    try {
      final deliveredTime = (deliveredAt as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(deliveredTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hr ago';
      } else {
        return '${difference.inDays} days ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  void _showRatingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RatingScreen(
          orderId: widget.orderId,
          orderData: widget.orderData,
          onRatingSubmitted: () {
            setState(() {
              _isRatingSubmitted = true;
            });
          },
        ),
      ),
    );
  }
}