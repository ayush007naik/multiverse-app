import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../services/delivery_fee_service.dart';
import 'payment_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _couponCode = '';
  double _discount = 0.0;

  void _applyCoupon() {
    if (_couponCode.toUpperCase() == 'SAVE50') {
      setState(() {
        _discount = 50.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coupon Applied! ₹50 Off'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Coupon Code'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _proceedToPayment() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    if (cart.items.isEmpty) return;

    double subtotal = cart.totalAmount;
    double distance = 0;

    // Calculate distance
    if (locationProvider.currentPosition != null &&
        cart.items.isNotEmpty &&
        cart.items.values.first.shopLat != null) {
      final firstItem = cart.items.values.first;
      distance = DeliveryFeeService.calculateDistance(
        userLat: locationProvider.currentPosition!.latitude,
        userLng: locationProvider.currentPosition!.longitude,
        shopLat: firstItem.shopLat!,
        shopLng: firstItem.shopLng!,
      );
    }

    // Calculate delivery fee based on distance tiers
    double deliveryFee;
    if (distance <= 2) {
      deliveryFee = 20;
    } else if (distance <= 5) {
      deliveryFee = 30;
    } else if (distance <= 10) {
      deliveryFee = 50;
    } else {
      deliveryFee = 80;
    }

    // Calculate GST: 18% of subtotal
    double gst = subtotal * 0.18;
    int gstRounded = gst.round();
    
    // Calculate total
    double totalDouble = subtotal + deliveryFee + gstRounded;
    int total = totalDouble.round();

    debugPrint('🛒 [Cart] Proceeding to payment');
    debugPrint('   Subtotal: ₹${subtotal.toStringAsFixed(0)}');
    debugPrint('   Distance: ${distance.toStringAsFixed(2)} km');
    debugPrint('   Delivery Fee: ₹${deliveryFee.toStringAsFixed(0)}');
    debugPrint('   GST (18%): ₹${gstRounded.toStringAsFixed(0)}');
    debugPrint('   Total: ₹${total.toStringAsFixed(0)}');

    final firstItem = cart.items.values.first;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          total: total,
          subtotal: subtotal,
          deliveryFee: deliveryFee,
          gst: gstRounded.toDouble(),
          shopName: firstItem.shopName,
          shopId: firstItem.shopId,
          vendorId: firstItem.vendorId,
          items: cart.items.values.map((i) => {
            'productId': i.id,
            'name': i.name,
            'price': i.price.toDouble(),
            'qty': i.quantity,
            'icon': i.image,
            'shopId': i.shopId,
            'vendorId': i.vendorId,
            'shopLat': i.shopLat,
            'shopLng': i.shopLng,
          }).toList(),
          deliveryDistance: distance,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'My Cart',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: cart.items.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (ctx, i) {
                      final item = cart.items.values.toList()[i];
                      final productId = cart.items.keys.toList()[i];
                      return _buildCartItem(productId, item, cart);
                    },
                  ),
                ),
                _buildOrderSummary(cart),
              ],
            ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 60,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add items from your favorite shops',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Start Shopping'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4F),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(String id, dynamic item, CartProvider cart) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(item.image, style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  item.shopName,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${item.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Color(0xFFFF4D4F),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => cart.removeSingleItem(id),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.remove,
                          size: 18,
                          color: item.quantity == 1
                              ? Colors.grey
                              : const Color(0xFFFF4D4F),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 35,
                      child: Center(
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => cart.addItem(
                        productId: id,
                        name: item.name,
                        price: item.price,
                        image: item.image,
                        shopId: item.shopId,
                        shopName: item.shopName,
                        vendorId: item.vendorId,
                        shopLat: item.shopLat,
                        shopLng: item.shopLng,
                        deliveryType: item.deliveryType,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.add,
                          size: 18,
                          color: const Color(0xFFFF4D4F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showRemoveDialog(context, id, item.name, cart),
                child: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRemoveDialog(
    BuildContext context,
    String id,
    String itemName,
    CartProvider cart,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Remove Item', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove $itemName from cart?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              cart.removeItem(id);
              Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(CartProvider cart) {
    final locationProvider = Provider.of<LocationProvider>(context);
    
    double subtotal = cart.totalAmount;
    double distance = 0;

    // Calculate distance
    if (locationProvider.currentPosition != null &&
        cart.items.isNotEmpty &&
        cart.items.values.first.shopLat != null) {
      final firstItem = cart.items.values.first;
      distance = DeliveryFeeService.calculateDistance(
        userLat: locationProvider.currentPosition!.latitude,
        userLng: locationProvider.currentPosition!.longitude,
        shopLat: firstItem.shopLat!,
        shopLng: firstItem.shopLng!,
      );
    }

    // Calculate delivery fee based on distance tiers
    double deliveryFee;
    if (distance <= 2) {
      deliveryFee = 20;
    } else if (distance <= 5) {
      deliveryFee = 30;
    } else if (distance <= 10) {
      deliveryFee = 50;
    } else {
      deliveryFee = 80;
    }

    // Calculate dynamic self-travel costs based on distance
    // Fuel cost: ₹10 per km
    double fuelCost = distance * 10;
    // Time cost: ₹5 per km equivalent
    double timeCost = distance * 5;
    // Other expenses: ₹3 per km
    double otherCost = distance * 3;
    // Total self-travel cost
    double selfTravelCost = fuelCost + timeCost + otherCost;
    
    // Calculate customer savings
    double savings = selfTravelCost - deliveryFee;
    if (savings < 0) savings = 0; // Don't show negative savings

    // Calculate GST: 18% of subtotal
    double gst = subtotal * 0.18;
    int gstRounded = gst.round();
    
    // Calculate total
    double totalDouble = subtotal + deliveryFee + gstRounded;
    int total = totalDouble.round();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Summary Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Column(
              children: [
                _summaryRow(
                  'Subtotal (${cart.totalItems} items)',
                  '₹${subtotal.toStringAsFixed(0)}',
                  fontSize: 15,
                ),
                const SizedBox(height: 8),
                _summaryRow(
                  'Delivery Fee',
                  '₹${deliveryFee.toStringAsFixed(0)}',
                  fontSize: 15,
                ),
                const SizedBox(height: 8),
                _summaryRow(
                  'GST (18%)',
                  '₹${gstRounded.toStringAsFixed(0)}',
                  fontSize: 15,
                ),
                const Divider(color: Color(0xFF333333), height: 24),
                _summaryRow(
                  'Total',
                  '₹${total.toStringAsFixed(0)}',
                  fontSize: 18,
                  color: const Color(0xFFFF4D4F),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Savings Box
          _buildSavingsBox(
            deliveryFee: deliveryFee,
            savings: savings,
            distance: distance,
            fuelCost: fuelCost,
            timeCost: timeCost,
            otherCost: otherCost,
            selfTravelCost: selfTravelCost,
          ),
          const SizedBox(height: 20),

          // Proceed Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _proceedToPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D4F),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Proceed to Payment',
                style: const TextStyle(
                  fontSize: 16,
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

  Widget _summaryRow(String label, String value, {Color color = Colors.grey, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey, fontSize: fontSize)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsBox({
    required double deliveryFee,
    required double savings,
    required double distance,
    required double fuelCost,
    required double timeCost,
    required double otherCost,
    required double selfTravelCost,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.savings_rounded,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance: ${distance.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, height: 1.4),
                        children: [
                          const TextSpan(
                            text: 'You saved ',
                            style: TextStyle(color: Color(0xFFAAAAAA)),
                          ),
                          TextSpan(
                            text: '₹${savings.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const TextSpan(
                            text: ' by choosing home delivery instead of travelling yourself.',
                            style: TextStyle(color: Color(0xFFAAAAAA)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _showSavingsDetails(
                deliveryFee: deliveryFee,
                savings: savings,
                distance: distance,
                fuelCost: fuelCost,
                timeCost: timeCost,
                otherCost: otherCost,
                selfTravelCost: selfTravelCost,
              ),
              child: const Text(
                'More',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF4CAF50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSavingsDetails({
    required double deliveryFee,
    required double savings,
    required double distance,
    required double fuelCost,
    required double timeCost,
    required double otherCost,
    required double selfTravelCost,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      height: 4,
                      width: 40,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(0xFF4CAF50),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Delivery Savings Breakdown',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Distance Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2196F3), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFF2196F3),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Shop Distance: ${distance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Color(0xFF2196F3),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Self Travel Cost Section
                  const Text(
                    'If you travel yourself:',
                    style: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _costItem('Fuel cost (₹10/km)', '₹${fuelCost.toStringAsFixed(0)}'),
                  _costItem('Time cost (₹5/km)', '₹${timeCost.toStringAsFixed(0)}'),
                  _costItem('Other expenses (₹3/km)', '₹${otherCost.toStringAsFixed(0)}'),
                  const Divider(color: Color(0xFF333333), height: 24),
                  _costItem(
                    'Total self-travel cost',
                    '₹${(selfTravelCost * 0.9).toStringAsFixed(0)}–₹${(selfTravelCost * 1.2).toStringAsFixed(0)}',
                    isTotal: true,
                  ),
                  const SizedBox(height: 24),

                  // Delivery Cost Section
                  const Text(
                    'With home delivery:',
                    style: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF4D4F), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'You only pay:',
                          style: TextStyle(
                            color: Color(0xFFAAAAAA),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '₹${deliveryFee.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFFFF4D4F),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Savings Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Your savings:',
                              style: TextStyle(
                                color: Color(0xFFAAAAAA),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '₹${savings.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Plus, you save your valuable time! ⏰',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Got it!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _costItem(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.white : const Color(0xFFAAAAAA),
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal ? const Color(0xFFFF4D4F) : Colors.white,
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
