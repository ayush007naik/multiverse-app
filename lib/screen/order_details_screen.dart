import 'package:db_compat/db_compat.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/premium_ui_widgets.dart';
import 'invoice_view_screen.dart';
import '../services/rating_service.dart';
import 'return_request_screen.dart';
import '../core/logging_service.dart';

class OrderDetailsScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  String _getShortOrderId(String id) {
    // Take first 8 characters and make it uppercase
    return id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080B),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6A3D)),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorState(context);
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          return _buildContent(context, data);
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080B),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, 'Order Details'),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Order not found',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final status = (data['status'] as String? ?? 'pending').toLowerCase();
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final shopName = data['shopName'] as String? ?? 'Multiverse Shop';
    final rawItems = data['items'];
    final items = rawItems is List ? rawItems : const <dynamic>[];
    final deliveryAddress = data['deliveryAddress'] as Map<String, dynamic>?;
    final createdAt = data['createdAt'] as Timestamp?;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, 'Order #${_getShortOrderId(orderId)}'),
            const SizedBox(height: 20),

            // Status Card
            _buildStatusCard(status),
            const SizedBox(height: 16),

            // Order Info Card
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .doc(data['shopId'] ?? data['vendorId'])
                  .snapshots(),
              builder: (context, shopSnap) {
                String liveShopName = shopName;
                if (shopSnap.hasData && shopSnap.data!.exists) {
                  final sData = shopSnap.data!.data() as Map<String, dynamic>;
                  liveShopName = sData['shopName'] ?? sData['name'] ?? shopName;
                }
                return _buildOrderInfoCard(liveShopName, total, createdAt);
              },
            ),
            const SizedBox(height: 16),

            // Items List
            if (items.isNotEmpty) ...[
              _buildSectionTitle('Order Items'),
              _buildItemsCard(items),
              const SizedBox(height: 16),
            ],

            // Delivery Address
            if (deliveryAddress != null) ...[
              _buildSectionTitle('Delivery Address'),
              _buildAddressCard(deliveryAddress),
              const SizedBox(height: 16),
            ],

            // Rider Info (if assigned)
            if (data['riderId'] != null) ...[
              _buildSectionTitle('Delivery Partner'),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('delivery_partners')
                    .doc(data['riderId'])
                    .snapshots(),
                builder: (context, riderSnapshot) {
                  if (!riderSnapshot.hasData || !riderSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }
                  final rider =
                      riderSnapshot.data!.data() as Map<String, dynamic>;
                  return GlassCard(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    borderRadius: 20,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: rider['profilePhotoUrl'] != null
                            ? CachedNetworkImageProvider(rider['profilePhotoUrl'])
                            : null,
                        child: rider['profilePhotoUrl'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        rider['name'] ?? 'Rider',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${rider['vehicleType'] ?? 'Bike'} • ${rider['vehicleNumber'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            (rider['rating'] as num?)
                                    ?.toDouble()
                                    .toStringAsFixed(1) ??
                                "5.0",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Payment Info
            _buildSectionTitle('Payment Details'),
            _buildPaymentCard(data, status),
            const SizedBox(height: 16),

            // Order Timeline
            _buildSectionTitle('Order Timeline'),
            _buildTimelineCard(status, createdAt),

            // Refund & Replacement Buttons (only for delivered orders)
            if (status == 'delivered') ...[
              const SizedBox(height: 16),
              _buildRefundReplacementButtons(context, data),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF15151A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'delivered':
        statusColor = const Color(0xFF4ADE80);
        statusIcon = Icons.check_circle_rounded;
        statusText = 'Delivered Successfully';
        break;
      case 'cancelled':
        statusColor = const Color(0xFFF87171);
        statusIcon = Icons.cancel_rounded;
        statusText = 'Order Cancelled';
        break;
      case 'preparing':
      case 'confirmed':
        statusColor = const Color(0xFFFFC94D);
        statusIcon = Icons.schedule_rounded;
        statusText = 'Order Confirmed';
        break;
      case 'on_the_way':
      case 'out_for_delivery':
        statusColor = const Color(0xFF43C6FF);
        statusIcon = Icons.delivery_dining_rounded;
        statusText = 'Out for Delivery';
        break;
      default:
        statusColor = const Color(0xFFFFC94D);
        statusIcon = Icons.pending_rounded;
        statusText = 'Order Pending';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.15),
            statusColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(statusIcon, color: statusColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(
    String shopName,
    double total,
    Timestamp? createdAt,
  ) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Order ID', _getShortOrderId(orderId)),
          const Divider(color: Colors.white24, height: 1),
          _buildInfoRow('Shop', shopName),
          const Divider(color: Colors.white24, height: 1),
          _buildInfoRow(
            'Order Date',
            createdAt != null ? _formatDateTime(createdAt) : 'N/A',
          ),
          const Divider(color: Colors.white24, height: 1),
          _buildInfoRow('Total Amount', '₹${total.round()}'),
        ],
      ),
    );
  }

  Widget _buildItemsCard(List items) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      borderRadius: 20,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(color: Colors.white24, height: 1),
            _buildItemTile(items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    final name = item['name'] ?? item['title'] ?? 'Item';
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6A3D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '$quantity',
                style: const TextStyle(
                  color: Color(0xFFFF6A3D),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '₹${price.toStringAsFixed(2)} each',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '₹${(price * quantity).toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> address) {
    final name = address['name'] ?? 'N/A';
    final phone = address['phone'] ?? 'N/A';
    final street = address['street'] ?? '';
    final city = address['city'] ?? '';
    final state = address['state'] ?? '';
    final pincode = address['pincode'] ?? '';

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: Color(0xFFFF6A3D),
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            phone,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '$street, $city, $state - $pincode',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> data, String status) {
    final paymentMethod = data['paymentMethod'] ?? 'Online';
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      borderRadius: 20,
      child: Column(
        children: [
          _buildInfoRow('Payment Method', paymentMethod),
          const Divider(color: Colors.white24, height: 1),
          _buildInfoRow(
            'Payment Status',
            (() {
              final method = (data['paymentMethod'] ?? 'Online')
                  .toString()
                  .toUpperCase();
              if (method == 'COD') {
                return status == 'delivered' ? 'PAID' : 'PENDING COD';
              }
              return 'PAID';
            })().toUpperCase(),
            valueColor: (() {
              final method = (data['paymentMethod'] ?? 'Online')
                  .toString()
                  .toUpperCase();
              if (method == 'COD' && status != 'delivered') {
                return const Color(0xFFF87171);
              }
              return const Color(0xFF4ADE80);
            })(),
          ),
          const Divider(color: Colors.white24, height: 1),
          _buildInfoRow('Amount Paid', '₹${total.round()}'),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(String status, Timestamp? createdAt) {
    final List<Map<String, dynamic>> timeline = [
      {
        'title': 'Order Placed',
        'completed': true,
        'time': createdAt != null ? _formatDateTime(createdAt) : 'N/A',
      },
      {
        'title': 'Order Confirmed',
        'completed': [
          'confirmed',
          'preparing',
          'on_the_way',
          'out_for_delivery',
          'delivered',
        ].contains(status),
        'time': '',
      },
      {
        'title': 'Out for Delivery',
        'completed': [
          'on_the_way',
          'out_for_delivery',
          'delivered',
        ].contains(status),
        'time': '',
      },
      {
        'title': 'Delivered',
        'completed': status == 'delivered',
        'time': status == 'delivered' ? 'Completed' : '',
      },
    ];

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      borderRadius: 20,
      child: Column(
        children: [
          for (int i = 0; i < timeline.length; i++) ...[
            if (i > 0) const Divider(color: Colors.white24, height: 1),
            _buildTimelineTile(timeline[i], i < timeline.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineTile(Map<String, dynamic> step, bool showLine) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(
            step['completed']
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            color: step['completed']
                ? const Color(0xFF4ADE80)
                : Colors.white.withValues(alpha: 0.2),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step['title'],
                  style: TextStyle(
                    color: step['completed'] ? Colors.white : Colors.white54,
                    fontSize: 15,
                    fontWeight: step['completed']
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                if (step['time']?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
                    step['time'],
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildRefundReplacementButtons(
    BuildContext context,
    Map<String, dynamic> orderData,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('E-Bill & Feedback'),

          // Invoice Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoiceViewScreen(orderId: orderId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text(
                    'View E-Bill',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoiceViewScreen(orderId: orderId),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.download_for_offline_outlined,
                    size: 18,
                  ),
                  label: const Text('Download', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Rating Section
          if (orderData['isRated'] == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Thanks for your feedback!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Show rating dialog or navigate to rating
                  _showRatingBottomSheet(context, orderData);
                },
                icon: const Icon(Icons.star_outline_rounded, size: 22),
                label: const Text(
                  'Rate your Experience',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFFF7A1A,
                  ).withValues(alpha: 0.1),
                  foregroundColor: const Color(0xFFFF7A1A),
                  side: const BorderSide(color: Color(0xFFFF7A1A)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

          const SizedBox(height: 24),
          _buildSectionTitle('Return Request'),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReturnRequestScreen(
                      orderId: orderId,
                      orderData: orderData,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.assignment_return_rounded, size: 22),
              label: const Text(
                'Return Request',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Available within 1 hour of delivery for broken/wrong items only',
            style: TextStyle(
              color: const Color(0xFF2196F3).withValues(alpha: 0.8),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showRatingBottomSheet(
    BuildContext context,
    Map<String, dynamic> order,
  ) {
    double shopRating = 5.0;
    double riderRating = 5.0;
    final TextEditingController shopReviewController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "RATE EXPERIENCE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                _buildRatingStars(
                  "Shop Rating",
                  shopRating,
                  (v) => setModalState(() => shopRating = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: shopReviewController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Share your feedback for the shop...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildRatingStars(
                  "Rider Rating",
                  riderRating,
                  (v) => setModalState(() => riderRating = v),
                ),

                const SizedBox(height: 40),

                if (isSubmitting)
                  const CircularProgressIndicator(color: Color(0xFFFF7A1A))
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Prevent multiple taps
                        if (isSubmitting) return;

                        setModalState(() => isSubmitting = true);
                        Log.i(
                          'OrderDetailsScreen',
                          '🚀 Starting rating submission for $orderId...',
                        );

                        try {
                          await RatingService.submitRating(
                            orderId: orderId,
                            shopRating: shopRating,
                            riderRating: riderRating,
                            shopReview: shopReviewController.text.trim().isEmpty ? null : shopReviewController.text.trim(),
                          );

                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("⭐⭐⭐⭐⭐ Thank you for your feedback!"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          Log.e(
                            'OrderDetailsScreen',
                            '❌ UI Rating Error: $e',
                            ex: e,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Failed to submit: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setModalState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A1A),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("SUBMIT RATINGS"),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingStars(
    String label,
    double rating,
    Function(double) onChanged,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (index) => IconButton(
              onPressed: () => onChanged(index + 1.0),
              icon: Icon(
                index < rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: index < rating ? Colors.amber : Colors.white12,
                size: 32,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
