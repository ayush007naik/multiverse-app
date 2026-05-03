import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../services/delivery_fee_service.dart';
import '../services/settings_service.dart';
import 'payment_screen.dart';
import 'add_address_screen.dart';
import 'shop_detail_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final SettingsService _settingsService = SettingsService();
  
  bool _isExpanded = false;
  String _selectedAddressId = '';
  Map<String, dynamic>? _selectedAddress;
  String _orderFor = 'myself';
  final TextEditingController _friendNameController = TextEditingController();
  final TextEditingController _friendPhoneController = TextEditingController();
  final TextEditingController _requestController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  
  String? _appliedCoupon;
  double _discount = 0.0;
  String _deliveryType = 'standard';
  
  double _distance = 0;
  double _deliveryFee = 0;
  
  @override
  void initState() {
    super.initState();
    _loadAddress();
    _calculateDistance();
  }
  
  Future<void> _loadAddress() async {
    final addressesStream = _settingsService.streamAddresses();
    await for (final addresses in addressesStream.take(1)) {
      if (addresses.isNotEmpty) {
        setState(() {
          _selectedAddress = addresses.first;
          _selectedAddressId = addresses.first['id'] ?? '';
        });
        break;
      }
    }
  }
  
  Future<void> _calculateDistance() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);
    
    if (locationProvider.currentPosition != null && cart.items.isNotEmpty) {
      final firstItem = cart.items.values.first;
      if (firstItem.shopLat != null) {
        final distance = DeliveryFeeService.calculateDistance(
          userLat: locationProvider.currentPosition!.latitude,
          userLng: locationProvider.currentPosition!.longitude,
          shopLat: firstItem.shopLat!,
          shopLng: firstItem.shopLng!,
        );
        
        double fee;
        if (distance <= 2) {
          fee = 20;
        } else if (distance <= 5) {
          fee = 30;
        } else if (distance <= 10) {
          fee = 50;
        } else {
          fee = 80;
        }
        
        if (_deliveryType == 'premium') {
          fee *= 1.5;
        }
        
        setState(() {
          _distance = distance;
          _deliveryFee = fee;
        });
      }
    }
  }
  
  void _applyCoupon() {
    final code = _couponController.text.trim().toUpperCase();
    if (code == 'SAVE50') {
      setState(() {
        _appliedCoupon = 'SAVE50';
        _discount = 50.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coupon Applied! ₹50 Off'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Coupon Code'), backgroundColor: Colors.red),
      );
    }
  }
  
  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _discount = 0.0;
      _couponController.clear();
    });
  }
  
  double _calculateSavings() {
    double selfTravelCost = _distance * 18;
    double savings = selfTravelCost - _deliveryFee;
    return savings > 0 ? savings : 0;
  }
  
  void _navigateToAddItems() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    
    if (cart.items.isEmpty || cart.currentShopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items in cart'), backgroundColor: Colors.red),
      );
      return;
    }
    
    // Create shop data map from cart info
    final shopData = {
      'id': cart.currentShopId,
      'name': cart.currentShopName,
      'category': '',
      'rating': 0.0,
      'eta': '',
      'open': true,
    };
    
    // Navigate to ShopDetailScreen to add more items
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopDetailScreen(shop: shopData),
      ),
    );
  }
  
  void _showSavingsBreakdown() {
    double fuelCost = _distance * 10;
    double timeCost = _distance * 5;
    double otherCost = _distance * 3;
    double selfTravelCost = fuelCost + timeCost + otherCost;
    double savings = _calculateSavings();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4, width: 40, margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const Text(
                  'Delivery Savings Details',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2196F3)),
                  ),
                  child: Text(
                    'Distance: ${_distance.toStringAsFixed(1)} km',
                    style: const TextStyle(color: Color(0xFF2196F3), fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('If you travel yourself:', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _costItem('Distance', '${_distance.toStringAsFixed(1)} km'),
                _costItem('Fuel used (10 kmpl)', '${(_distance / 10).toStringAsFixed(2)} L'),
                _costItem('Fuel cost (₹100/L)', '₹${fuelCost.toStringAsFixed(0)}'),
                _costItem('Time cost (₹5/km)', '₹${timeCost.toStringAsFixed(0)}'),
                _costItem('Other expenses (₹3/km)', '₹${otherCost.toStringAsFixed(0)}'),
                const Divider(color: Color(0xFF333333), height: 24),
                _costItem('Total self-travel cost', '₹${selfTravelCost.toStringAsFixed(0)}', isTotal: true),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('You pay for delivery:', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
                          Text('₹${_deliveryFee.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('You saved ₹${savings.toStringAsFixed(0)} + your time!', style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _costItem(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isTotal ? Colors.white : const Color(0xFFAAAAAA), fontSize: isTotal ? 14 : 13, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: isTotal ? const Color(0xFFFF4D4F) : Colors.white, fontSize: isTotal ? 16 : 13, fontWeight: isTotal ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final firstItem = cart.items.isNotEmpty ? cart.items.values.first : null;
    
    double subtotal = cart.totalAmount;
    double gst = subtotal * 0.18;
    int gstRounded = gst.round();
    double total = subtotal + _deliveryFee + gstRounded - _discount;
    double savings = _calculateSavings();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  _buildAddressSection(),
                  _buildOrderForSection(),
                  _buildItemsList(cart),
                  _buildAddItemsAndRequest(),
                  _buildCouponSection(),
                  _buildDeliveryType(),
                  _buildBillDetails(subtotal, gstRounded, total, savings),
                ],
              ),
            ),
          ),
          _buildBottomButton(total),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: const Color(0xFF2A2A2A), width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.translucent,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Checkout',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAddressSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFFFF4D4F), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delivery Address', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      _selectedAddress != null ? '${_selectedAddress!['name'] ?? ''} - ${_selectedAddress!['address'] ?? ''}' : 'Select delivery address',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF888888), size: 24),
                ),
              ),
            ],
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2A2A2A)),
            const SizedBox(height: 12),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _settingsService.streamAddresses(),
              builder: (context, snapshot) {
                final addresses = snapshot.data ?? [];
                if (addresses.isEmpty) {
                  return const Text('No saved addresses', style: TextStyle(color: Color(0xFF888888), fontSize: 13));
                }
                return Column(
                  children: addresses.map((addr) {
                    final isSelected = addr['id'] == _selectedAddressId;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedAddress = addr;
                          _selectedAddressId = addr['id'] ?? '';
                          _isExpanded = false;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFF4D4F).withValues(alpha: 0.1) : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFF333333)),
                        ),
                        child: Row(
                          children: [
                            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFF888888), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(addr['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(addr['address'] ?? '', style: const TextStyle(color: Color(0xFF888888), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddAddressScreen()));
                _loadAddress();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFF4D4F), width: 1.5), borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_location_alt_rounded, color: Color(0xFFFF4D4F), size: 20),
                    SizedBox(width: 8),
                    Text('Add New Address', style: TextStyle(color: Color(0xFFFF4D4F), fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildOrderForSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('You are ordering for', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _orderForOption('myself', 'Myself', Icons.person_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _orderForOption('friend', 'For Friend', Icons.group_rounded)),
            ],
          ),
          if (_orderFor == 'friend') ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF2A2A2A)),
            const SizedBox(height: 12),
            TextField(
              controller: _friendNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Friend\'s Name',
                hintStyle: const TextStyle(color: Color(0xFF666666)),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.person, color: Color(0xFFFF4D4F)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _friendPhoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Friend\'s Phone Number',
                hintStyle: const TextStyle(color: Color(0xFF666666)),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.phone, color: Color(0xFFFF4D4F)),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _orderForOption(String value, String label, IconData icon) {
    final isSelected = _orderFor == value;
    return GestureDetector(
      onTap: () => setState(() => _orderFor = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? const LinearGradient(colors: [Color(0xFFFF4D4F), Color(0xFFE64A19)]) : null,
          color: isSelected ? null : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFF333333)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF888888), size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF888888), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildItemsList(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ordered Items', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...cart.items.values.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(item.image ?? '', style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Qty: ${item.quantity}', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                    ],
                  ),
                ),
                Text('₹${(item.price * item.quantity).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildAddItemsAndRequest() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _navigateToAddItems(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFF4D4F), width: 1.5), borderRadius: BorderRadius.circular(12)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_shopping_cart_rounded, color: Color(0xFFFF4D4F), size: 20),
                  SizedBox(width: 8),
                  Text('Add Items', style: TextStyle(color: Color(0xFFFF4D4F), fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _requestController,
            maxLines: 2,
            maxLength: 200,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Any special request? (Optional)',
              hintStyle: const TextStyle(color: Color(0xFF666666)),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF4D4F))),
              prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFFFF4D4F), size: 20),
              counterStyle: const TextStyle(color: Color(0xFF888888), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCouponSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: _appliedCoupon != null ? _buildAppliedCoupon() : _buildCouponInput(),
    );
  }
  
  Widget _buildCouponInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _couponController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter coupon code',
              hintStyle: const TextStyle(color: Color(0xFF666666)),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2A2A2A))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF4D4F))),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _applyCoupon,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF4D4F), Color(0xFFE64A19)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAppliedCoupon() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF4CAF50).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coupon Applied: $_appliedCoupon', style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 14, fontWeight: FontWeight.w600)),
                Text('Discount: ₹${_discount.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(onTap: _removeCoupon, child: const Icon(Icons.close_rounded, color: Color(0xFF888888), size: 20)),
        ],
      ),
    );
  }
  
  Widget _buildDeliveryType() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _deliveryTypeOption('standard', 'Standard', 'Delivery may be slightly delayed due to order batching', Icons.schedule_rounded),
          const SizedBox(height: 12),
          _deliveryTypeOption('premium', 'Premium', 'Faster delivery, no order batching, priority delivery', Icons.flash_on_rounded),
        ],
      ),
    );
  }
  
  Widget _deliveryTypeOption(String value, String label, String description, IconData icon) {
    final isSelected = _deliveryType == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _deliveryType = value;
          _calculateDistance();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF4D4F).withValues(alpha: 0.1) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFF2A2A2A), width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFF888888), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFFAAAAAA), fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
                ],
              ),
            ),
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFF888888), size: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBillDetails(double subtotal, int gstRounded, double total, double savings) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bill Details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _billRow('Item Total', '₹${subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _billRow('Delivery Fee (${_distance.toStringAsFixed(1)} km)', '₹${_deliveryFee.toStringAsFixed(0)}'),
          const Padding(padding: EdgeInsets.only(left: 4, top: 2, bottom: 8), child: Text('Free delivery above ₹699', style: TextStyle(color: Color(0xFF888888), fontSize: 11))),
          _billRow('GST & Other Charges', '₹${gstRounded.toStringAsFixed(0)}'),
          if (_discount > 0) ...[
            const SizedBox(height: 8),
            _billRow('Coupon Discount', '-₹${_discount.toStringAsFixed(0)}', valueColor: const Color(0xFF4CAF50)),
          ],
          const Divider(color: Color(0xFF333333), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('To Pay', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4CAF50), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_rounded, color: Color(0xFF4CAF50), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You saved ₹${savings.toStringAsFixed(0)} using delivery',
                    style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _billRow(String label, String value, {Color valueColor = Colors.white}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
  
  Widget _buildBottomButton(double total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: GestureDetector(
        onTap: () => _proceedToPayment(total),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF4D4F), Color(0xFFD32F2F)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFFFF4D4F).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Proceed to Pay ₹${total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
  
  void _proceedToPayment(double total) {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select delivery address'), backgroundColor: Colors.red),
      );
      return;
    }
    
    final cart = Provider.of<CartProvider>(context, listen: false);
    final firstItem = cart.items.values.first;
    
    // Get special request text (trim and handle empty)
    final specialRequest = _requestController.text.trim();
    
    HapticFeedback.mediumImpact();
    
    debugPrint('📝 [Checkout] Special Request: "$specialRequest"');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          total: total.round(),
          subtotal: cart.totalAmount,
          deliveryFee: _deliveryFee,
          gst: cart.totalAmount * 0.18,
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
          deliveryDistance: _distance,
          specialRequest: specialRequest, // 👈 Pass special request to payment screen
        ),
      ),
    );
  }
}
