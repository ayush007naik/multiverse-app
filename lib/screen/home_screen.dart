import 'dart:ui';
import '../services/branding_service.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'checkout_screen.dart';
import 'order_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'shop_detail_screen.dart';
import 'cart_screen.dart';
import 'real_estate_screen.dart';
import 'bookings_screen.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../services/shop_service.dart';
import '../services/settings_service.dart';
import '../utils/delivery_fee_calculator.dart';
import 'location_picker_screen.dart';
import '../widgets/banner_slider.dart';
import '../widgets/shop_card.dart';
import '../widgets/offer_slider.dart';
import '../widgets/premium_ui_widgets.dart';
import '../widgets/category_card.dart';
import 'movies_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool showTracking;
  final Map<String, dynamic>? orderData;

  const HomeScreen({
    super.key,
    this.showTracking = false,
    this.orderData,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;
  final ShopService _shopService = ShopService();
  final BrandingService _brandingService = BrandingService();
  final SettingsService _settingsService = SettingsService();
  String _selectedCategory = "All";
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _nearbyOnly = false;
  String _sortBy = 'default'; // ← ADD
  static const double _nearbyRadiusKm = 10.0;
  
  // Track Order Popup State
  bool _showTrackingBar = false;

  // Local state for immediate location update
  String _selectedLocation = "Tap to set location";

  final List<String> _filters = [
    "Filters",
    "New to you",
    "Great offers",
    "Sort by"
  ];
  String _activeFilter = "Filters";

  @override
  void initState() {
    super.initState();
    
    // Show tracking bar if coming from order success
    _showTrackingBar = widget.showTracking;
    
    if (_showTrackingBar) {
      // Auto-hide after 8 seconds
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted) {
          setState(() {
            _showTrackingBar = false;
          });
        }
      });
    }
  }

  //  Demo Shops (Fallback when Firestore is empty)
  final List<Map<String, dynamic>> demoShops = [
    {
      'id': 's1',
      'name': 'Sharma Hardware Store',
      'category': 'Hardware',
      'rating': 4.8,
      'eta': '20-25 min',
      'icon': '',
      'color': 0xFFFF9800,
      'open': true,
      'items': [
        {'id': 'i1', 'name': 'Hammer', 'price': 250, 'icon': ''},
        {'id': 'i2', 'name': 'Screwdriver Set', 'price': 450, 'icon': ''},
        {'id': 'i3', 'name': 'Steel Nails (1kg)', 'price': 120, 'icon': ''},
      ],
    },
    {
      'id': 's2',
      'name': 'Mandi Fashion Hub',
      'category': 'Clothing',
      'rating': 4.5,
      'eta': '15-20 min',
      'icon': '',
      'color': 0xFFE91E63,
      'open': true,
      'items': [
        {'id': 'i4', 'name': 'Cotton T-Shirt', 'price': 599, 'icon': ''},
        {'id': 'i5', 'name': 'Blue Jeans', 'price': 1299, 'icon': ''},
      ],
    },
    {
      'id': 's3',
      'name': 'Shiv Medical Store',
      'category': 'Pharmacy',
      'rating': 4.9,
      'eta': '10-15 min',
      'icon': '',
      'color': 0xFF2196F3,
      'open': true,
      'items': [
        {'id': 'i6', 'name': 'Vitamin C Tabs', 'price': 90, 'icon': ''},
        {'id': 'i7', 'name': 'First Aid Kit', 'price': 350, 'icon': ''},
      ],
    },
    {
      'id': 's4',
      'name': 'Pahadi Dhaba',
      'category': 'Food',
      'rating': 4.7,
      'eta': '30-40 min',
      'icon': '',
      'color': 0xFF4CAF50,
      'open': true,
      'items': [
        {'id': 'i8', 'name': 'Paneer Tikka', 'price': 220, 'icon': ''},
        {'id': 'i9', 'name': 'Dal Makhani', 'price': 180, 'icon': ''},
      ],
    },
  ];

  //  Categories (using Unsplash images instead of emojis)
  final List<Map<String, String>> categories = [
    {'icon': '', 'name': 'Food'},
    {'icon': '', 'name': 'Grocery'},
    {'icon': '', 'name': 'Medicines'},
    {'icon': '', 'name': 'Fashion'},
    {'icon': '', 'name': 'Beauty'},
    {'icon': '', 'name': 'Electronics'},
    {'icon': '', 'name': 'Furniture'},
    {'icon': '', 'name': 'Stationery'},
    {'icon': '', 'name': 'Services'},
    {'icon': '', 'name': 'Gifts'},
    {'icon': '', 'name': 'Pet Care'},
  ];

  //  Offers
  final List<Map<String, String>> offers = [
    {
      'title': '60% OFF on Selected Shops',
      'sub': 'Limited time deals on top stores',
      'color1': '0xFFFF4D4F',
      'color2': '0xFFD32F2F',
      'tag': '🔥 Trending',
    },
    {
      'title': 'Free Delivery',
      'sub': 'Orders above ₹699',
      'color1': '0xFF6200EA',
      'color2': '0xFF2196F3',
      'tag': '🚚 Special Offer',
    },
    {
      'title': 'Welcome Offer',
      'sub': 'Extra ₹100 off on first 3 orders',
      'color1': '0xFF4CAF50',
      'color2': '0xFF2E7D32',
      'tag': '🎁 New User',
    },
  ];

  //  Demo Properties
  final List<Map<String, dynamic>> demoProperties = [
    {
      'id': 'p1',
      'title': 'Luxury Villa in Mandi',
      'price': '₹45,00,000',
      'location': 'Indira Colony, Mandi',
      'type': 'Buy',
      'image':
          'https://images.unsplash.com/photo-1580587767526-cf3671a05014?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    },
    {
      'id': 'p2',
      'title': 'Modern 2BHK Apartment',
      'price': '₹15,000/mo',
      'location': 'Mandi Bazaar',
      'type': 'Rent',
      'image':
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    },
    {
      'id': 'p3',
      'title': 'Cozy Hilltop Cottage',
      'price': '₹25,000/mo',
      'location': 'Talyahar, Mandi',
      'type': 'Rent',
      'image':
          'https://images.unsplash.com/photo-1518780664697-55e3ad937233?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
    },
  ];
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _sortOption('default', 'Relevance'),
            _sortOption('rating', 'Rating (High to Low)'),
            _sortOption('distance', 'Distance (Nearest)'),
            _sortOption('name', 'Name (A-Z)'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sortOption(String value, String label) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF4D4F).withValues(alpha: 0.15)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF4D4F) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFF4D4F) : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFFF4D4F), size: 20),
          ],
        ),
      ),
    );
  }

  void _showFiltersDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filters',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Nearby Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFFFF4D4F)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Nearby only (10km)', style: TextStyle(color: Colors.white)),
                    ),
                    Switch(
                      value: _nearbyOnly,
                      onChanged: (val) {
                        setModalState(() {});
                        setState(() => _nearbyOnly = val);
                      },
                      activeColor: const Color(0xFFFF4D4F),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D4F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _shopService.streamActiveShops(),
      builder: (context, snapshot) {
        final shops = snapshot.data ?? [];
        return Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          body: Stack(
            children: [
              // Premium Dark Gradient Background
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0D0D0D),
                      Color(0xFF1A1A1A),
                      Color(0xFF0D0D0D),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Subtle Orange Glow
              Positioned(
                top: -100,
                right: -50,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF4D4F).withValues(alpha: 0.05),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
              _getBody(
                shops,
                snapshot.connectionState == ConnectionState.waiting,
              ),
              Consumer<CartProvider>(
                builder: (context, cart, child) {
                  if (cart.itemCount > 0 && _selectedTab == 0 && !_showTrackingBar) {
                    return _buildCartBar(cart);
                  }
                  return const SizedBox.shrink();
                },
              ),
              // Track Order Popup (Swiggy Style)
              if (_showTrackingBar && widget.orderData != null)
                _buildTrackOrderPopup(),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildCartBar(CartProvider cart) {
    // Get shop name from cart items
    String shopName = 'Shop';
    if (cart.items.isNotEmpty) {
      final firstItem = cart.items.values.first;
      shopName = firstItem.shopName ?? 'Shop';
    }

    return Positioned(
      bottom: 110, // Adjusted for bottom nav
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CheckoutScreen(),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4D4F), Color(0xFFD32F2F)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D4F).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                // Left side: Shop info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shopName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cart.itemCount} Item${cart.itemCount > 1 ? 's' : ''} • All items',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right side: Checkout button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Checkout',
                    style: TextStyle(
                      color: Color(0xFFFF4D4F),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Track Order Popup (Swiggy Style)
  Widget _buildTrackOrderPopup() {
    return Positioned(
      bottom: 110, // Adjusted for bottom nav
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderTrackingScreen(
                orderId: widget.orderData?['orderId'] ?? '',
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF4D4F), Color(0xFFD32F2F)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Order Confirmed",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${widget.orderData?['shopName'] ?? 'Your Order'} • ${widget.orderData?['estimatedTime'] ?? '20-25 min'}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Track ➝",
                  style: TextStyle(
                    color: Color(0xFFFF4D4F),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //  Function to return different widgets based on _selectedTab
  Widget _getBody(List<Map<String, dynamic>> shops, bool isLoading) {
    switch (_selectedTab) {
      case 0:
        return _buildHomeContent(shops, isLoading);
      case 1:
        return const RealEstateScreen();
      case 2:
        return const BookingsScreen(); // Services
      case 3:
        return const MoviesScreen();   // Movies - naya banayenge
      case 4:
        return const CartScreen();
      default:
        return _buildHomeContent(shops, isLoading);
    }
  }


  //  Refactored Home Content
   Widget _buildHomeContent(List<Map<String, dynamic>> shops, bool isLoading) {
     final locationProvider = context.watch<LocationProvider>();
     final currentPosition = locationProvider.currentPosition;

     // Add distance to shops
     final shopsWithDistance = shops.map((shop) {
       final distance = currentPosition == null
           ? null
           : ShopService.distanceKmForShop(
               shop,
               userLat: currentPosition.latitude,
               userLng: currentPosition.longitude,
             );
       return {
         ...shop,
         'distanceKm': distance,
         'distanceLabel': distance == null
             ? null
             : DeliveryFeeCalculator.formatDistance(distance),
       };
     }).toList();

     // Filter shops
     final filteredShops = shopsWithDistance.where((s) {
       // Category Filter
       if (_selectedCategory != "All") {
         final shopCategory = s['category']?.toString().trim().toLowerCase() ?? '';
         final selectedCategory = _selectedCategory.trim().toLowerCase();

         // Match specific category names or "Pharmacy" with "Medicines" etc.
         bool matches = shopCategory == selectedCategory;

         // Handle common mapping aliases
         if (!matches) {
           if (selectedCategory == "medicines") matches = shopCategory == "pharmacy";
           if (selectedCategory == "pharmacy") matches = shopCategory == "medicines";
           if (selectedCategory == "fashion") matches = shopCategory == "clothing";
           if (selectedCategory == "clothing") matches = shopCategory == "fashion";
         }

         if (!matches) return false;
       }

       final name = s['name'].toString().toLowerCase();
       final cat = s['category'].toString().toLowerCase();
       final location = ShopService.locationLabelFromData(s).toLowerCase();
       final query = _searchQuery.toLowerCase();
       final searchMatch =
           name.contains(query) ||
           cat.contains(query) ||
           location.contains(query);
       if (!searchMatch) return false;

       if (!_nearbyOnly) return true;
       final distance = s['distanceKm'] as double?;
       return distance != null && distance <= _nearbyRadiusKm;
     }).toList();

     // Sort filtered shops
     final sortedShops = List<Map<String, dynamic>>.from(filteredShops);
     if (_sortBy == 'rating') {
       sortedShops.sort((a, b) =>
           (b['rating'] as num? ?? 0).compareTo(a['rating'] as num? ?? 0));
     } else if (_sortBy == 'distance') {
       sortedShops.sort((a, b) {
         final aD = a['distanceKm'] as double? ?? 999;
         final bD = b['distanceKm'] as double? ?? 999;
         return aD.compareTo(bD);
       });
     } else if (_sortBy == 'name') {
       sortedShops.sort((a, b) =>
           (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
     } else {
       // Default: sort by distance
       sortedShops.sort((a, b) {
         final aDistance = a['distanceKm'] as double? ?? 999;
         final bDistance = b['distanceKm'] as double? ?? 999;
         return aDistance.compareTo(bDistance);
       });
     }

     return SafeArea(
       child: SingleChildScrollView(
         physics: const BouncingScrollPhysics(),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             FadeSlideAnimation(
               delay: const Duration(milliseconds: 100),
               child: _buildHeader(shopsWithDistance),
             ),
             FadeSlideAnimation(
               delay: const Duration(milliseconds: 200),
               child: _buildSearchBar(),
             ),

             FadeSlideAnimation(
               delay: const Duration(milliseconds: 300),
               child: _buildOfferSlider(),
             ),

             const SizedBox(height: 20),

             // Categories Horizontal List
             FadeSlideAnimation(
               delay: const Duration(milliseconds: 400),
               child: _buildCategories(),
             ),

             // Filter Chips
             FadeSlideAnimation(
               delay: const Duration(milliseconds: 450),
               child: _buildFilterChips(),
             ),

             Padding(
               padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
               child: Text(
                 _selectedCategory == "All"
                     ? 'Featured Shops'
                     : '$_selectedCategory Shops',
                 style: const TextStyle(
                   color: Colors.white,
                   fontSize: 20,
                   fontWeight: FontWeight.w900,
                   letterSpacing: 0.5,
                 ),
               ),
             ),

             isLoading
                 ? const Center(
                     child: Padding(
                       padding: EdgeInsets.all(40.0),
                       child: CircularProgressIndicator(
                         color: Color(0xFFFF4D4F),
                       ),
                     ),
                   )
                 : AnimatedSwitcher(
                     duration: const Duration(milliseconds: 400),
                     child: sortedShops.isEmpty
                         ? _buildEmptyShopsState(
                             _searchQuery.isEmpty
                                 ? 'No shops available in this category'
                                 : 'No shops matching "$_searchQuery"',
                           )
                         : FadeSlideAnimation(
                             key: ValueKey(_selectedCategory + _searchQuery),
                             delay: const Duration(milliseconds: 100),
                       child: _buildShopsList(sortedShops),

                     ),
                   ),

             const SizedBox(height: 120), // Bottom padding for nav bar
           ],
         ),
       ),
     );
   }

  Widget _buildShopFilters(int resultCount, LocationProvider locationProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          _shopFilterChip(
            label: 'All Shops',
            selected: !_nearbyOnly,
            onTap: () => setState(() => _nearbyOnly = false),
          ),
          const SizedBox(width: 10),
          _shopFilterChip(
            label: 'Nearby',
            selected: _nearbyOnly,
            onTap: () async {
              if (locationProvider.currentPosition == null) {
                await locationProvider.updateLocation();
              }
              if (!mounted) return;
              setState(() => _nearbyOnly = true);
            },
          ),
          const Spacer(),
          if (locationProvider.isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFF4D4F),
              ),
            )
          else
            Text(
              '$resultCount found',
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _shopFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF4D4F) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFFFF4D4F) : const Color(0xFF272727),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFBBBBBB),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyShopsState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            const Icon(
              Icons.storefront_outlined,
              color: Color(0xFF333333),
              size: 50,
            ),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationPicker() async {
    debugPrint('📍 Opening Location Picker');
    HapticFeedback.mediumImpact();
    
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => const LocationPickerScreen(),
    );

    if (result != null && mounted) {
      debugPrint('📍 Result from location picker: $result');
      
      // Handle both string and map results
      String address;
      if (result is Map) {
        // New format with coordinates
        address = result['address'] as String;
        final lat = result['latitude'] as double?;
        final lng = result['longitude'] as double?;
        
        if (lat != null && lng != null) {
          debugPrint('📍 Location coordinates: lat=$lat, lng=$lng');
          // Store coordinates in provider for distance calculations
          context.read<LocationProvider>().updateCoordinates(lat, lng);
        }
      } else {
        // Legacy string format
        address = result as String;
      }
      
      // Update global provider as well to ensure persistence across screens
      context.read<LocationProvider>().setSelectedAddress(address);
      setState(() {
        _selectedLocation = address;
      });
    }
  }

  Widget _buildLocationOption(
    BuildContext context,
    String title, 
    String subtitle, {
    VoidCallback? onTap, 
    IconData icon = Icons.location_on_outlined,
    bool isSelected = false,
    bool isLoading = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFF4D4F).withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFFFF4D4F).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF4D4F).withValues(alpha: 0.2) : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF4D4F)))
              : Icon(icon, color: isSelected ? const Color(0xFFFF4D4F) : Colors.white70, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isSelected ? Colors.white70 : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF4D4F), size: 20) : null,
        onTap: onTap,
      ),
    );
  }

  //  Header
  Widget _buildHeader(List<Map<String, dynamic>> shops) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D).withValues(alpha: 0.8),
          ),
          child: Row(
            children: [
              // Logo
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4D4F).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Location
              Expanded(
                child: GestureDetector(
                  onTap: _showLocationPicker,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFFF4D4F),
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Delivering to',
                            style: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedLocation.isNotEmpty ? _selectedLocation : 'Tap to set location',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF888888),
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Notification bell
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Profile avatar
              GestureDetector(
                onTap: () {
                  print("Profile Clicked");
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4D4F), Color(0xFFD32F2F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D4F).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //  Search Bar
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _shopService.streamActiveShops(),
        builder: (context, snapshot) {
          final shops = snapshot.data ?? [];
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchScreen(shops: shops),
                ),
              );
            },
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF333333)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFFFF4D4F),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Search shops, food, products...',
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  //  Offers Banner (horizontal scroll)
  Widget _buildOffersBanner() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _brandingService.streamOffers(),
      builder: (context, snapshot) {
        final offersList = snapshot.data ?? [];
        
        // Use local offers as fallback when Firebase is empty
        final displayOffers = offersList.isEmpty ? offers : offersList;
        
        // Filter out old/invalid offers
        final filteredOffers = displayOffers.where((offer) {
          final title = offer['title']?.toString().toLowerCase() ?? '';
          // Remove old offers
          return !title.contains('50% off') && 
                 !title.contains('₹100 cashback') &&
                 !title.contains('first order');
        }).toList();
        
        // DEBUG: Print what banners are being displayed
        debugPrint('🎯 BANNER DEBUG: Total offers = ${filteredOffers.length}');
        for (var offer in filteredOffers) {
          debugPrint('   Banner: ${offer['title']} - ${offer['sub']}');
        }
        
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: SizedBox(
            key: const ValueKey('banners_v2_updated'), // Force rebuild
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: filteredOffers.length,
              itemBuilder: (ctx, i) {
                final o = filteredOffers[i];
                final c1 = Color(int.parse(o['color1'] ?? '0xFFFF4D4F'));
                final c2 = Color(int.parse(o['color2'] ?? '0xFFD32F2F'));
                final tag = o['tag']; // Optional tag like "🔥 Trending"
                return GestureDetector(
                  onTap: () => HapticFeedback.lightImpact(),
                  child: Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [c1, c2]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: c1.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Optional Tag (e.g., "🔥 Trending")
                        if (tag != null && tag.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          o['title'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          o['sub'] ?? '',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    );
  }

  //  Banner Slider (carousel)
  Widget _buildBannerSlider() {
    // Sample image URLs for the banner slider
    final List<String> imageUrls = [
      'https://picsum.photos/800/400?random=1',
      'https://picsum.photos/800/400?random=2',
      'https://picsum.photos/800/400?random=3',
    ];
    
    // Use offers data for titles and subtitles
    final List<String> titles = [];
    final List<String> subtitles = [];
    
    // Get up to 3 offers for titles/subtitles
    final offersList = offers.take(imageUrls.length).toList();
    for (var offer in offersList) {
      titles.add(offer['title'] ?? 'Offer');
      subtitles.add(offer['sub'] ?? 'Special deal');
    }
    
    // Pad lists if needed
    while (titles.length < imageUrls.length) {
      titles.add('Offer');
      subtitles.add('Special deal');
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SizedBox(
        height: 220,
        child: BannerSlider(
          imageUrls: imageUrls,
          titles: titles,
          subtitles: subtitles,
          onTap: (index) {
            debugPrint('Banner $index tapped');
          },
        ),
      ),
    );
  }

  //  Offer Slider
  Widget _buildOfferSlider() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _brandingService.streamOffers(),
      builder: (context, snapshot) {
        final offersList = snapshot.data ?? [];
        
        // Use local offers as fallback and convert to Map<String, String>
        final rawOffers = offersList.isEmpty ? offers : offersList;
        final List<Map<String, String>> formattedOffers = rawOffers.map((o) {
          return {
            'title': o['title']?.toString() ?? '',
            'sub': o['sub']?.toString() ?? '',
            'color1': o['color1']?.toString() ?? '0xFFFF4D4F',
            'color2': o['color2']?.toString() ?? '0xFFD32F2F',
            'tag': o['tag']?.toString() ?? '',
          };
        }).toList();

        return OfferSlider(offers: formattedOffers);
      },
    );
  }

  //  Section Title
  Widget _buildSectionTitle(String title, {required VoidCallback onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: const Text(
              'See all →',
              style: TextStyle(
                color: Color(0xFFFF4D4F),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();

                if (filter == 'Sort by') {
                  _showSortDialog();
                  return;
                }

                if (filter == 'Filters') {
                  _showFiltersDialog();
                  return;
                }

                if (filter == 'New to you') {
                  setState(() {
                    _activeFilter = filter;
                    _sortBy = 'default';
                    _nearbyOnly = false;
                  });
                  return;
                }

                if (filter == 'Great offers') {
                  setState(() => _activeFilter = filter);
                  return;
                }

                setState(() => _activeFilter = filter);
              },

              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF4D4F).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFF333333),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFFBBBBBB),
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    if (filter == "Filters" || filter == "Sort by") ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: isSelected ? const Color(0xFFFF4D4F) : const Color(0xFFBBBBBB),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ️ Categories Grid (horizontal)
  Widget _buildCategories() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _brandingService.streamCategories(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> categoriesListFromStream = snapshot.data ?? [];
        
        // 1. Combine lists (Stream + Fallback)
        final combinedList = [
          ...categoriesListFromStream,
          ...categories,
        ];
        
        // 2. Filter out duplicates using a Set of names
        final Set<String> seenNames = {};
        final List<Map<String, dynamic>> uniqueCategories = [];
        
        for (var cat in combinedList) {
          final name = cat['name']?.toString() ?? '';
          if (name.isNotEmpty && !seenNames.contains(name.toLowerCase())) {
            seenNames.add(name.toLowerCase());
            uniqueCategories.add(cat);
          }
        }

        // 3. Add "All" category at the beginning
        final List<Map<String, dynamic>> finalCategories = [
          {'icon': '', 'name': 'All'},
          ...uniqueCategories,
        ];

        return SizedBox(
          height: 105,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: finalCategories.length,
            itemBuilder: (ctx, i) {
              final cat = finalCategories[i];
              final isSelected = _selectedCategory.toLowerCase() == (cat['name']?.toString().toLowerCase() ?? '');
              
              return CategoryCard(
                name: cat['name'] ?? '',
                icon: cat['icon'] ?? '🏪',
                isSelected: isSelected,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _selectedCategory = cat['name'] ?? 'All';
                  });
                },
              );
            },
          ),
        );
      }
    );
  }

  //  Shops List
  Widget _buildShopsList(List<Map<String, dynamic>> shops) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: shops.length,
      itemBuilder: (ctx, i) {
        final shop = shops[i];
        return ShopCard(
          shop: shop,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ShopDetailScreen(shop: shop),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.apartment_rounded, 'label': 'Real Estate'},
      {'icon': Icons.handyman_rounded, 'label': 'Services'},
      {'icon': Icons.movie_rounded, 'label': 'Movies'},
      {'icon': Icons.shopping_cart_rounded, 'label': 'Cart'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D).withValues(alpha: 0.8),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              currentIndex: _selectedTab,
              onTap: (i) {
                HapticFeedback.lightImpact();
                setState(() => _selectedTab = i);
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFFFF4D4F),
              unselectedItemColor: const Color(0xFF666666),
              selectedFontSize: 12,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
              type: BottomNavigationBarType.fixed,
              items: items
                  .map(
                    (item) => BottomNavigationBarItem(
                  icon: Icon(item['icon'] as IconData, size: 24),
                  label: item['label'] as String,
                ),
              )
                  .toList(),
             ),
           ),
         ),
       ),
     );
   }
}
