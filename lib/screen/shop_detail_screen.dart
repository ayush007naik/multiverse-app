import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'checkout_screen.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../services/shop_service.dart';
import '../utils/delivery_fee_calculator.dart';
import '../widgets/category_card.dart';

class ShopDetailScreen extends StatefulWidget {
  final Map<String, dynamic> shop;
  const ShopDetailScreen({super.key, required this.shop});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  String _selectedCategory = 'All';

  Stream<List<Map<String, dynamic>>> _getProducts() {
    final shopId = widget.shop['id'] as String? ?? '';
    
    print(' [ShopDetail] Loading products for shopId: $shopId');
    print(' [ShopDetail] Shop data: ${widget.shop}');
    
    if (shopId.isEmpty) {
      print('⚠️ [ShopDetail] shopId is EMPTY! Shop: ${widget.shop}');
      return Stream.value([]);
    }
    
    // Use ProductProvider stream
    return context.read<ProductProvider>().streamShopProducts(shopId);
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final shopName = widget.shop['name'] as String? ?? 'Shop';

    final List<Map<String, String>> categoriesList = [
      {'icon': '🍔', 'name': 'Food'},
      {'icon': '🛒', 'name': 'Grocery'},
      {'icon': '💊', 'name': 'Pharmacy'},
      {'icon': '👗', 'name': 'Fashion'},
      {'icon': '💄', 'name': 'Beauty'},
      {'icon': '📱', 'name': 'Electronics'},
      {'icon': '🛋️', 'name': 'Furniture'},
      {'icon': '📚', 'name': 'Stationery'},
      {'icon': '🛠️', 'name': 'Services'},
      {'icon': '🎁', 'name': 'Gifts'},
      {'icon': '🐾', 'name': 'Pet Care'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      bottomNavigationBar: cart.itemCount > 0 ? _buildCartBar(cart) : null,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getProducts(),
        builder: (context, snapshot) {
          // Handle connection states properly to prevent flickering
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('⏳ [ShopDetail] Products loading...');
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
            );
          }

          // Handle errors with detailed logging
          if (snapshot.hasError) {
            print('❌ [ShopDetail] ERROR loading products:');
            print('   Error: ${snapshot.error}');
            print('   Stack Trace: ${snapshot.stackTrace}');
            print('   ConnectionState: ${snapshot.connectionState}');
            print('   Shop ID: ${widget.shop['id']}');
            
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading products',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4D4F),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Get products from Firestore (no fallback to demo items)
          final products = snapshot.data ?? [];
          print('✅ [ShopDetail] Loaded ${products.length} products');

          final productCategories = [
            'All',
            ...products
                .map((p) => p['category'] as String? ?? 'General')
                .toSet(),
          ];
          final filteredProducts = _selectedCategory == 'All'
              ? products
              : products
                    .where((p) => p['category'] == _selectedCategory)
                    .toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildShopInfo()),
              if (products.isNotEmpty)
                SliverToBoxAdapter(child: _buildCategoryFilter(productCategories, categoriesList)),
              if (products.isEmpty)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text(
                        "No items available in this shop",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: cart.itemCount > 0 
                      ? const EdgeInsets.only(bottom: 100)
                      : const EdgeInsets.only(bottom: 20),
                  sliver: SliverToBoxAdapter(
                    child: _buildProductsList(
                      cart,
                      shopName,
                      filteredProducts,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0D0D0D),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.shop['image'] ?? 'https://via.placeholder.com/400',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    const Color(0xFF0D0D0D),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopInfo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.shop['name'] ?? 'Shop Name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.shop['category'] ?? 'Category',
            style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(
                ShopService.locationLabelFromData(widget.shop),
                style: const TextStyle(color: Colors.grey),
              ),
              const Spacer(),
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                widget.shop['rating']?.toString() ?? '4.5',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(List<String> productCategories, List<Map<String, String>> globalCategories) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: productCategories.length,
        itemBuilder: (ctx, i) {
          final catName = productCategories[i];
          final isSelected = _selectedCategory == catName;
          
          // Find emoji from global categories
          String emoji = '📦';
          if (catName == 'All') {
            emoji = '🍽️';
          } else {
            final globalCat = globalCategories.firstWhere(
              (c) => c['name']!.toLowerCase() == catName.toLowerCase(),
              orElse: () => {'icon': '📦', 'name': catName},
            );
            emoji = globalCat['icon']!;
          }

          return CategoryCard(
            name: catName,
            icon: emoji,
            isSelected: isSelected,
            size: 60,
            onTap: () => setState(() => _selectedCategory = catName),
          );
        },
      ),
    );
  }

  Widget _buildProductsList(
    CartProvider cart,
    String shopName,
    List<Map<String, dynamic>> products,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${products.length} items',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
          ),
          const SizedBox(height: 12),
          ...products.map((p) => _buildProductCard(p, cart, shopName)),
        ],
      ),
    );
  }

  void _handleAddToCart(
    CartProvider cart,
    String id,
    Map<String, dynamic> p,
    String shopName,
  ) {
    if (cart.items.isNotEmpty && cart.items.values.first.shopId != (widget.shop['id'] ?? 's1')) {
      _showClearCartDialog(cart, id, p, shopName);
      return;
    }
    final shopLat = _readCoordinate(widget.shop, ['lat', 'latitude']);
    final shopLng = _readCoordinate(widget.shop, ['lng', 'longitude']);
    final deliveryType = _resolveDeliveryType(p);
    final vendorId =
        widget.shop['vendorId'] as String? ??
        widget.shop['ownerId'] as String? ??
        widget.shop['userId'] as String?;

    cart.addItem(
      productId: id,
      name: p['name'] ?? 'Product',
      price: (p['price'] as num?)?.toDouble() ?? 0.0,
      image: p['imageUrl'] ?? p['image'] ?? p['icon'] ?? '',
      shopId: widget.shop['id'] ?? 's1',
      shopName: shopName,
      vendorId: vendorId,
      shopLat: shopLat,
      shopLng: shopLng,
      deliveryType: deliveryType,
    );
  }

  String _resolveDeliveryType(Map<String, dynamic> product) {
    final explicitType =
        product['deliveryType'] ??
        product['itemType'] ??
        product['weightCategory'] ??
        product['shippingCategory'];
    if (explicitType is String) {
      return DeliveryFeeCalculator.normalizeDeliveryType(explicitType);
    }

    if (product['isHeavy'] == true) {
      return DeliveryFeeCalculator.heavyDeliveryType;
    }

    final weight = product['weightKg'] ?? product['weight'];
    if (weight is num && weight >= 10) {
      return DeliveryFeeCalculator.heavyDeliveryType;
    }

    return DeliveryFeeCalculator.normalDeliveryType;
  }

  double? _readCoordinate(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }

    final location = data['location'];
    if (location is Map<String, dynamic>) {
      for (final key in keys) {
        final value = location[key];
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value);
      }
    }

    try {
      if (keys.contains('lat')) return (location.latitude as num).toDouble();
      if (keys.contains('lng')) return (location.longitude as num).toDouble();
    } catch (_) {
      return null;
    }

    return null;
  }

  void _showClearCartDialog(
    CartProvider cart,
    String id,
    Map<String, dynamic> p,
    String shopName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear cart?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your cart contains items from another shop. Do you want to clear it and add this item?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('NO', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              cart.clear();
              _handleAddToCart(cart, id, p, shopName);
              Navigator.pop(ctx);
            },
            child: const Text(
              'YES',
              style: TextStyle(color: Color(0xFFFF4D4F)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> p,
    CartProvider cart,
    String shopName,
  ) {
    final id = p['id'] as String;
    final inStock = p['inStock'] as bool? ?? true;
    final cartItem = cart.items[id];
    final qty = cartItem?.quantity ?? 0;

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
          // Product icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                p['icon'] as String? ?? '',
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name'] as String? ?? 'Product',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFB300),
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${p['rating'] ?? '0.0'}',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'per ${p['unit'] ?? 'unit'}',
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${p['price'] ?? '0'}',
                  style: const TextStyle(
                    color: Color(0xFFFF4D4F),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          // Add / Remove buttons
          if (!inStock)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Out of\nStock',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (qty == 0)
            GestureDetector(
              onTap: () => _handleAddToCart(cart, id, p, shopName),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D4F),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'ADD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4F),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => cart.removeSingleItem(id),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Icon(Icons.remove, color: Colors.white, size: 16),
                    ),
                  ),
                  Text(
                    '$qty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _handleAddToCart(cart, id, p, shopName),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Icon(Icons.add, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartBar(CartProvider cart) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Item count text above button
          Text(
            '${cart.totalItems} item${cart.totalItems > 1 ? 's' : ''} added',
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          // Checkout button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4F),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4D4F).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_bag_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Checkout ₹${cart.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
