import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:db_compat/db_compat.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/coupon_model.dart';
import '../services/coupon_service.dart';
import '../services/marketplace_search_service.dart';
import 'shop_detail_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

/// Marketplace Search Results Screen
/// Shows shops, products, and offers - ONLY from marketplace
class MarketplaceSearchResultsScreen extends StatefulWidget {
  final String searchQuery;

  const MarketplaceSearchResultsScreen({super.key, required this.searchQuery});

  @override
  State<MarketplaceSearchResultsScreen> createState() =>
      _MarketplaceSearchResultsScreenState();
}

class _MarketplaceSearchResultsScreenState
    extends State<MarketplaceSearchResultsScreen> {
  final MarketplaceSearchService _searchService = MarketplaceSearchService();
  String _selectedTab = 'all'; // 'all', 'shops', 'products', 'offers'
  late String _currentQuery;

  Map<String, List<Map<String, dynamic>>> _searchResults = {
    'shops': [],
    'products': [],
    'offers': [],
  };

  bool _isLoading = true;
  late TextEditingController _searchController;
  Map<String, String> _maxOffersMap = {};
  StreamSubscription<QuerySnapshot>? _offerSub;

  void _listenToShopOffers() {
    _offerSub = FirebaseFirestore.instance
        .collection('coupons')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          final Map<String, double> tempMaxDiscounts = {};
          final Map<String, String> tempOfferStrings = {};

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final coupon = CouponModel.fromMap(data, doc.id);
            final isNewFormat = data['type'] != null;
            final legacylessCoupon = isNewFormat
                ? null
                : CouponModel.fromLegacyMap(data, doc.id);
            final effective = isNewFormat ? coupon : legacylessCoupon;

            if (effective == null || effective.isExpired) continue;

            final display = effective.displayDiscount;
            final label = effective.discountLabel;
            if (display <= 0 && effective.type != CouponType.freeDelivery) {
              continue;
            }

            final keys = {
              (data['shopId'] ?? data['shop_id'] ?? '').toString(),
              (data['vendorId'] ?? data['vendor_id'] ?? '').toString(),
              (data['theatreId'] ?? '').toString(),
              (data['ownerId'] ?? '').toString(),
            };

            for (final key in keys) {
              if (key.isNotEmpty) {
                if (display > (tempMaxDiscounts[key] ?? 0.0)) {
                  tempMaxDiscounts[key] = display;
                  tempOfferStrings[key] = label;
                  // Track view for the best coupon found for this shop/vendor
                  if (effective.id != null) {
                    CouponService.trackView(effective.id!);
                  }
                }
              }
            }
          }

          if (mounted) {
            setState(() {
              _maxOffersMap = tempOfferStrings;
            });
          }
        });
  }

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.searchQuery;
    _searchController = TextEditingController(text: widget.searchQuery);
    _listenToShopOffers();
    _performSearch();
  }

  @override
  void dispose() {
    _offerSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);

    final results = await _searchService.searchAll(widget.searchQuery);

    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

  String? _getMaxOffer(Map<String, dynamic> shop) {
    final shopId = (shop['id'] ?? shop['shopId'] ?? '').toString();
    final vendorId =
        (shop['vendorId'] ?? shop['ownerId'] ?? shop['userId'] ?? '')
            .toString();

    if (shopId.isNotEmpty && _maxOffersMap.containsKey(shopId)) {
      return _maxOffersMap[shopId];
    }
    if (vendorId.isNotEmpty && _maxOffersMap.containsKey(vendorId)) {
      return _maxOffersMap[vendorId];
    }

    String? offer;
    if (shop['maxOffer'] != null) {
      offer = shop['maxOffer'].toString();
    } else if (shop['discount'] != null)
      offer = shop['discount'].toString();

    if (offer == null) {
      final coupons = shop['coupons'];
      if (coupons is List && coupons.isNotEmpty) {
        double maxDiscount = 0;
        for (var coupon in coupons) {
          if (coupon is Map) {
            final discount = (coupon['discount'] as num?)?.toDouble() ?? 0;
            if (discount > maxDiscount) maxDiscount = discount;
          }
        }
        if (maxDiscount > 0) offer = '${maxDiscount.toInt()}%';
      }
    }

    if (offer != null) {
      if (!offer.contains('%')) offer = '$offer%';
      return offer;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: _buildSearchBar(),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab Selector
          _buildTabSelector(),

          const SizedBox(height: 16),

          // Results Count
          if (!_isLoading) _buildResultsCount(),

          const SizedBox(height: 8),

          // Search Results
          Expanded(
            child: _isLoading ? _buildLoadingState() : _buildResultsContent(),
          ),
        ],
      ),
    );
  }

  // ========== SEARCH BAR ==========

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF7A1A).withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            setState(() {
              _currentQuery = value;
            });
            _performSearch();
          }
        },
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search marketplace...',
          hintStyle: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFFFF7A1A),
            size: 20,
          ),
        ),
      ),
    );
  }

  // ========== TAB SELECTOR ==========

  Widget _buildTabSelector() {
    final tabs = ['all', 'shops', 'products', 'offers'];
    final labels = ['All', 'Shops', 'Products', 'Offers'];
    final icons = [
      Icons.apps_rounded,
      Icons.store_rounded,
      Icons.shopping_bag_rounded,
      Icons.local_offer_rounded,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == tabs[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = tabs[index]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFF7A1A)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFFF7A1A,
                            ).withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  children: [
                    Icon(
                      icons[index],
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      size: 18,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labels[index],
                      style: GoogleFonts.poppins(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ========== RESULTS COUNT ==========

  Widget _buildResultsCount() {
    final totalResults =
        _searchResults['shops']!.length +
        _searchResults['products']!.length +
        _searchResults['offers']!.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$totalResults results found',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          Text(
            '"$_currentQuery"',
            style: GoogleFonts.poppins(
              color: const Color(0xFFFF7A1A),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ========== LOADING STATE ==========

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFFF7A1A),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Searching Multiverse...',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ========== RESULTS CONTENT ==========

  Widget _buildResultsContent() {
    if (_searchResults['shops']!.isEmpty &&
        _searchResults['products']!.isEmpty &&
        _searchResults['offers']!.isEmpty) {
      return _buildEmptyState();
    }

    switch (_selectedTab) {
      case 'shops':
        return _buildShopsResults();
      case 'products':
        return _buildProductsResults();
      case 'offers':
        return _buildOffersResults();
      default:
        return _buildAllResults();
    }
  }

  // ========== EMPTY STATE ==========

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 20),
          Text(
            'No results found',
            style: GoogleFonts.orbitron(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ========== ALL RESULTS ==========

  Widget _buildAllResults() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Shops Section
        if (_searchResults['shops']!.isNotEmpty) ...[
          _buildSectionHeader('Shops', _searchResults['shops']!.length),
          ..._searchResults['shops']!
              .take(3)
              .map((shop) => _buildShopCard(shop)),
          const SizedBox(height: 24),
        ],

        // Products Section
        if (_searchResults['products']!.isNotEmpty) ...[
          _buildSectionHeader('Products', _searchResults['products']!.length),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _searchResults['products']!.length.clamp(0, 5),
              itemBuilder: (context, index) {
                final product = _searchResults['products']![index];
                return _buildProductCard(product);
              },
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Offers Section
        if (_searchResults['offers']!.isNotEmpty) ...[
          _buildSectionHeader('Offers', _searchResults['offers']!.length),
          ..._searchResults['offers']!
              .take(3)
              .map((offer) => _buildOfferCard(offer)),
        ],
      ],
    );
  }

  // ========== SHOPS RESULTS ==========

  Widget _buildShopsResults() {
    if (_searchResults['shops']!.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults['shops']!.length,
      itemBuilder: (context, index) {
        final shop = _searchResults['shops']![index];
        return _buildShopCard(shop);
      },
    );
  }

  // ========== PRODUCTS RESULTS ==========

  Widget _buildProductsResults() {
    if (_searchResults['products']!.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _searchResults['products']!.length,
      itemBuilder: (context, index) {
        final product = _searchResults['products']![index];
        return _buildProductGridCard(product);
      },
    );
  }

  // ========== OFFERS RESULTS ==========

  Widget _buildOffersResults() {
    if (_searchResults['offers']!.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults['offers']!.length,
      itemBuilder: (context, index) {
        final offer = _searchResults['offers']![index];
        return _buildOfferCard(offer);
      },
    );
  }

  // ========== SECTION HEADER ==========

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.orbitron(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF7A1A).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF7A1A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== SHOP CARD ==========

  Widget _buildShopCard(Map<String, dynamic> shop) {
    final name = shop['name'] as String? ?? 'Shop';
    final category = shop['category'] as String? ?? '';
    final rating = shop['rating'] as num? ?? 0.0;

    final dynamicOffer = _getMaxOffer(shop);
    final offer = dynamicOffer != null
        ? 'UPTO $dynamicOffer OFF'
        : (shop['offer'] as String? ?? '');
    final image = shop['image'] as String? ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF7A1A).withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            // Shop Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: image,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      memCacheWidth: 200,
                      maxWidthDiskCache: 400,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholder: (_, __) => _buildShopPlaceholder(),
                      errorWidget: (_, __, ___) => _buildShopPlaceholder(),
                    )
                  : _buildShopPlaceholder(),
            ),
            const SizedBox(width: 16),

            // Shop Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (offer.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF7A1A,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            offer,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFF7A1A),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.store_rounded, color: Colors.white24, size: 40),
    );
  }

  // ========== PRODUCT CARD (Horizontal) ==========

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] as String? ?? 'Product';
    final basePrice = (product['price'] as num?)?.toDouble() ?? 0.0;
    final discount = (product['discount'] as num?)?.toDouble() ?? 0.0;
    final price =
        (product['finalPrice'] as num?)?.toDouble() ??
        (basePrice * (1 - (discount / 100)));
    final image = (product['imageUrl'] ?? product['image'] ?? '') as String;

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      memCacheWidth: 320,
                      maxWidthDiskCache: 400,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      placeholder: (_, __) => _buildProductPlaceholder(),
                      errorWidget: (_, __, ___) => _buildProductPlaceholder(),
                    )
                  : _buildProductPlaceholder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${price.round().toString()}',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFFFF7A1A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (discount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '₹${basePrice.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    color: Colors.white24,
                    fontSize: 10,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ========== PRODUCT GRID CARD ==========

  Widget _buildProductGridCard(Map<String, dynamic> product) {
    final name = product['name'] as String? ?? 'Product';
    final basePrice = (product['price'] as num?)?.toDouble() ?? 0.0;
    final discount = (product['discount'] as num?)?.toDouble() ?? 0.0;
    final price =
        (product['finalPrice'] as num?)?.toDouble() ??
        (basePrice * (1 - (discount / 100)));
    final image = (product['imageUrl'] ?? product['image'] ?? '') as String;
    final shopName = product['shopName'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to product detail
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: image.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        memCacheWidth: 320,
                        maxWidthDiskCache: 400,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (_, __) =>
                            _buildProductPlaceholder(),
                        errorWidget: (_, __, ___) =>
                            _buildProductPlaceholder(),
                      )
                    : _buildProductPlaceholder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '₹${price.round().toString()}',
              style: GoogleFonts.orbitron(
                color: const Color(0xFFFF7A1A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (shopName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                shopName,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.shopping_bag_rounded,
        color: Colors.white24,
        size: 40,
      ),
    );
  }

  // ========== OFFER CARD ==========

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final title = offer['title'] as String? ?? 'Offer';
    final description = offer['description'] as String? ?? '';
    final shopName = offer['shopName'] as String? ?? '';
    final validUntil = offer['validUntil'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF7A1A).withValues(alpha: 0.15),
            const Color(0xFF7D4CFF).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF7A1A).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'OFFER',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              if (validUntil != null)
                Text(
                  'Valid till ${_formatDate(validUntil)}',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
          if (shopName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'From: $shopName',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF7A1A),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}
