import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:db_compat/db_compat.dart';
import 'package:rxdart/rxdart.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../providers/order_provider.dart';
import '../models/coupon_model.dart';
import '../models/payment_method.dart';
import '../services/coupon_service.dart';
import '../services/delivery_fee_service.dart';
import '../services/google_maps_directions_service.dart';
import '../services/runtime_config_service.dart';
import '../services/settings_service.dart';
import '../services/shop_delivery_service.dart';
import '../services/analytics_event_service.dart';
import '../services/shop_service.dart';
import 'shop_detail_screen.dart';
import 'order_success_screen.dart';
import 'payment_processing_screen.dart';
import 'checkout_cart_view.dart';
import 'checkout_address_picker.dart';
import 'checkout_order_summary.dart';
import 'premium_payment_screen.dart';
import '../core/logging_service.dart';

/// Premium Zomato-style checkout screen with modern UI
class CheckoutScreenV2 extends StatefulWidget {
  const CheckoutScreenV2({super.key});

  @override
  State<CheckoutScreenV2> createState() => _CheckoutScreenV2State();
}

class _CheckoutScreenV2State extends State<CheckoutScreenV2>
    with TickerProviderStateMixin {
  final SettingsService _settingsService = SettingsService();

  // Stream subscriptions
  StreamSubscription? _addressSubscription;
  StreamSubscription? _deliverySubscription;
  StreamSubscription? _couponSubscription;
  Timer? _savingsDebounceTimer;
  final ShopDeliveryService _deliveryService = ShopDeliveryService();
  bool _deliveryAvailable = false;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // State
  Map<String, dynamic>? _selectedAddress;
  double _deliveryFee = 0;
  double _distance = 0;
  int _estimatedDeliveryTime = 0; // in minutes
  StreamSubscription? _addressStreamSubscription;
  String _paymentMethod = 'ONLINE'; // 'ONLINE' or 'COD'
  bool _isGstRegistered = true; // Default to true until fetched
  bool _isProcessing = false;
  bool _isUpdatingDelivery = false;
  String? _deliveryRadiusError;
  double _tipAmount = 0.0;

  // Savings - Start at 0, calculated dynamically on load
  double _realtimeSavings = 0.0;
  Map<String, dynamic>? _savingsBreakdown;
  final ValueNotifier<double> _savingsNotifier = ValueNotifier<double>(0.0);

  // Vendor coupons
  double _couponDiscount = 0.0;
  String? _appliedCouponCode;
  List<CouponModel> _vendorOffers = [];
  CouponModel? _appliedOffer;

  // Controllers
  final TextEditingController _shopNoteController = TextEditingController();
  final TextEditingController _deliveryNoteController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkShopGstStatus();

    // Fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    AnalyticsEventService.log('checkout_start', props: {
      'shopName': Provider.of<CartProvider>(context, listen: false).currentShopName,
    });

    // Load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAddress();
        _calculateDeliveryFee();
        _calculateSavings();
        _loadVendorCoupons();
        _checkDeliveryAvailability();
      }
    });
  }

  Future<void> _checkShopGstStatus() async {
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final shopId = cart.currentShopId;
      if (shopId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _isGstRegistered = doc.data()?['isGstRegistered'] ?? true;
          });
        }
      }
    } catch (e) {
      Log.e('CheckoutScreen', 'Error fetching GST status: $e');
    }
  }

  @override
  void dispose() {
    _addressSubscription?.cancel();
    _addressStreamSubscription?.cancel();
    _deliverySubscription?.cancel();
    _couponSubscription?.cancel();
    _deliveryService.dispose();
    _savingsDebounceTimer?.cancel();
    _fadeController.dispose();
    _shopNoteController.dispose();
    _deliveryNoteController.dispose();
    _noteFocusNode.dispose();
    _couponController.dispose();
    _savingsNotifier.dispose();
    super.dispose();
  }

  // ========== DATA LOADING ==========

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadAddress() async {
    try {
      // Cancel existing subscription if any
      _addressStreamSubscription?.cancel();

      // Listen to address changes in real-time
      _addressStreamSubscription = _settingsService.streamAddresses().listen((
        addresses,
      ) {
        if (!mounted) return;

        if (addresses.isNotEmpty) {
          // Find selected address or use first one
          Map<String, dynamic>? addressToUse;

          if (_selectedAddress != null) {
            final String currentId = _selectedAddress?['id'] ?? '';
            addressToUse = addresses.firstWhere(
              (addr) => addr['id'] == currentId,
              orElse: () => addresses.first,
            );
          } else {
            addressToUse = addresses.firstWhere(
              (addr) => addr['isDefault'] == true,
              orElse: () => addresses.first,
            );
          }

          setState(() {
            _selectedAddress = addressToUse;
          });

          Log.i('CheckoutScreen', '📍 Address updated: ${_selectedAddress?['name']}');

          // Recalculate delivery when address changes
          _calculateDeliveryFee();
          if (_selectedAddress != null) {
            _checkAddressDeliveryRadius(_selectedAddress!);
          }
        } else {
          setState(() {
            _selectedAddress = null;
          });
        }
      });
    } catch (e) {
      Log.e('CheckoutScreen', 'Error loading address: $e');
    }
  }

  Future<void> _calculateDeliveryFee({
    Map<String, dynamic>? addressOverride,
  }) async {
    try {
      if (!mounted) return;
      final loc = Provider.of<LocationProvider>(context, listen: false);
      final cart = Provider.of<CartProvider>(context, listen: false);

      if (cart.items.isEmpty) return;
      final firstItem = cart.items.values.first;

      // Use the freshly selected address (if provided), else selected state,
      // else GPS. Address coords always win so delivery reflects the address.
      final Map<String, dynamic>? addrToUse = addressOverride ?? _selectedAddress;
      double? userLat;
      double? userLng;

      if (addrToUse != null && addrToUse['lat'] != null) {
        userLat = (addrToUse['lat'] as num).toDouble();
        userLng = (addrToUse['lng'] as num).toDouble();
        Log.i(
          'CheckoutScreen',
          '🚚 [DeliveryCalc] Using address coords: ($userLat, $userLng)'
          ' for ${addrToUse['id']}',
        );
      } else if (loc.currentPosition != null) {
        userLat = loc.currentPosition!.latitude;
        userLng = loc.currentPosition!.longitude;
      }

      // Check if shop coordinates are available
      if (firstItem.shopLat == null || firstItem.shopLng == null) {
        Log.w('CheckoutScreen', 'Shop coordinates not available, using default delivery fee');
        if (mounted) {
          setState(() {
            _distance = 5.0; // Default 5km
            _deliveryFee = 45.0; // Default fee: ₹20 base + (5km × ₹5) = ₹45
            _estimatedDeliveryTime = 30; // Default 30 mins
          });
          _calculateSavings();
        }
        return;
      }

      if (userLat != null && userLng != null) {
        Log.i('CheckoutScreen', '📍 [DistanceCheck] User address: ($userLat, $userLng)');
        Log.i('CheckoutScreen', '📍 [DistanceCheck] Shop coords: (${firstItem.shopLat}, ${firstItem.shopLng})');

        // Try Google Maps Directions API for actual road distance
        double distance;
        int etaMinutes;
        try {
          final directions = await GoogleMapsDirectionsService.getDirections(
            origin: LatLng(userLat, userLng),
            destination: LatLng(firstItem.shopLat!, firstItem.shopLng!),
          );
          if (directions != null && directions.distanceValue > 0) {
            distance = directions.distanceValue / 1000.0; // meters to km
            const basePrepTime = 15;
            etaMinutes = basePrepTime + (directions.durationValue / 60).round();
            Log.i('CheckoutScreen', '📍 [Directions] Road distance: ${distance.toStringAsFixed(1)}km, ETA: $etaMinutes mins (incl. ${basePrepTime}min prep)');
          } else {
            throw Exception('No directions result');
          }
        } catch (e) {
          Log.w('CheckoutScreen', '[Directions] API failed, using Haversine fallback: $e');
          distance = DeliveryFeeService.calculateDistance(
            userLat: userLat,
            userLng: userLng,
            shopLat: firstItem.shopLat!,
            shopLng: firstItem.shopLng!,
          );
          const basePrepTime = 15;
          const avgTravelTimePerKm = 4;
          etaMinutes = (basePrepTime + (distance * avgTravelTimePerKm)).round();
        }

        if (!mounted) return;

        // Calculate delivery fee based on actual road distance
        final fee = DeliveryFeeService.calculateFeeFromDistance(distance);

        Log.i('CheckoutScreen', '🚚 Delivery Calculated: ${distance.toStringAsFixed(1)}km, Fee: ₹${fee.toInt()}, ETA: $etaMinutes mins');

        setState(() {
          _distance = distance;
          _deliveryFee = fee;
          _estimatedDeliveryTime = etaMinutes;
        });

        _calculateSavings();
      } else {
        Log.w('CheckoutScreen', 'User location not available, using default delivery fee');
        if (mounted) {
          setState(() {
            _distance = 5.0; // Default 5km
            _deliveryFee = 45.0; // Default fee
            _estimatedDeliveryTime = 30;
          });
          _calculateSavings();
        }
      }
    } catch (e) {
      Log.e('CheckoutScreen', 'Error calculating delivery: $e');
      // Fallback to default fee on error
      if (mounted) {
        setState(() {
          _distance = 5.0;
          _deliveryFee = 45.0;
          _estimatedDeliveryTime = 30;
        });
      }
    }
  }

  Future<void> _calculateSavings() async {
    // Cancel any existing debounce
    _savingsDebounceTimer?.cancel();

    // Calculate instantly without debounce
    if (!mounted) return;

    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) {
      _updateSavings(0.0); // No savings if cart is empty
      return;
    }

    try {
      // REAL CALCULATION - Single source of truth
      // Total Savings = Fuel Cost Saved + Parking Avoided

      // 1. Calculate fuel cost based on actual distance
      double fuelCost = 0;
      if (_distance > 0) {
        // Formula: (round trip distance / vehicle mileage) * fuel price
        // Assuming: 12 km/l mileage, ₹103/l petrol price (average India)
        final double roundTripDistance = _distance * 2; // To shop and back
        const double mileage = 12.0; // km/l (average bike mileage)
        const double fuelPrice = 103.0; // ₹/liter (average petrol price)
        final double litersNeeded = roundTripDistance / mileage;
        fuelCost = litersNeeded * fuelPrice;
      } else {
        // Default estimate if distance not calculated yet (8km round trip)
        fuelCost = (16 / 12) * 103; // ≈ ₹137
      }

      // 2. Calculate parking cost (dynamic based on location type)
      double parkingCost = 0;
      if (_distance > 5) {
        // Long distance = likely commercial area = higher parking
        parkingCost = 50;
      } else if (_distance > 2) {
        // Medium distance = shopping area = medium parking
        parkingCost = 40;
      } else {
        // Short distance = local market = lower parking
        parkingCost = 30;
      }

      // 3. COMPUTED TOTAL SAVINGS = Fuel + Parking (single source of truth)
      final double fuelCostSaved = fuelCost;
      final double parkingSaved = parkingCost;
      final double totalSaved = fuelCostSaved + parkingSaved;

      // Use actual calculated savings (no artificial limits)
      final double totalSavings = totalSaved;

      // Update instantly
      _updateSavings(totalSavings);

      // Update breakdown with SAME data (single source of truth)
      if (mounted) {
        setState(() {
          _savingsBreakdown = {
            'fuelCost': fuelCost,
            'parkingCost': parkingCost,
            'totalSavings': totalSavings, // ← Outside card shows this
            'distance': _distance > 0 ? _distance : 8.0,
            'roundTripDistance': _distance > 0 ? (_distance * 2) : 16.0,
            'timeSaved': _distance > 0 ? (_distance * 4 + 10).round() : 45,
            'mileage': 12.0, // km/l
            'fuelPrice': 103.0, // ₹/liter
          };
        });
      }

      Log.i('CheckoutScreen', '💰 Savings calculated: ₹${totalSavings.toStringAsFixed(0)} (Fuel: ₹${fuelCost.toStringAsFixed(0)}, Parking: ₹${parkingCost.toStringAsFixed(0)}, Distance: ${_distance.toStringAsFixed(1)}km)');
    } catch (e) {
      Log.e('CheckoutScreen', 'Savings calculation error: $e');
      // Fallback with real estimate (not dummy)
      // Based on 8km round trip: ₹137 fuel + ₹30 parking = ₹167
      _updateSavings(167.0);
      if (mounted) {
        setState(() {
          _savingsBreakdown = {
            'fuelCost': 137.0,
            'parkingCost': 30.0,
            'totalSavings': 167.0, // Computed: ₹137 fuel + ₹30 parking
            'distance': 8.0,
            'roundTripDistance': 16.0,
            'timeSaved': 45,
            'mileage': 12.0,
            'fuelPrice': 103.0,
          };
        });
      }
    }
  }

  // Instant savings update with animation
  void _updateSavings(double newSavings) {
    if (!mounted) return;

    // Update state instantly
    setState(() {
      _realtimeSavings = newSavings;
    });

    // Update notifier for smooth animations
    _savingsNotifier.value = newSavings;
  }

  Future<void> _loadVendorCoupons() async {
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      if (cart.items.isEmpty) return;

      final firstItem = cart.items.values.first;
      final vendorId = firstItem.vendorId;

      if (vendorId == null || vendorId.isEmpty) {
        Log.w('CheckoutScreen', 'No vendorId found in cart items');
        return;
      }

      Log.i('CheckoutScreen', '🔍 Loading vendor coupons for vendor: $vendorId');

      // Cancel existing subscription
      _couponSubscription?.cancel();

      // Combine vendor-specific and ADMIN coupons
      final vendorStream = CouponService.streamActiveByVendor(vendorId);
      final adminStream = CouponService.streamActiveByVendor('ADMIN');

      _couponSubscription = CombineLatestStream.list([
        vendorStream,
        adminStream,
      ]).listen((snapshots) {
        if (!mounted) return;

        final Set<String> uniqueCodes = {};
        final List<CouponModel> allCoupons = [];

        for (var snapshot in snapshots) {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final coupon = CouponModel.fromMap(data, doc.id);
            final code = coupon.code.toUpperCase();

            if (code.isNotEmpty &&
                !uniqueCodes.contains(code) &&
                coupon.matchesScope(CouponModel.scopeMarketplace)) {
              // Apply shop-level filtering for vendor coupons if vendorId matches shop owner
              // but ADMIN coupons are always included
              if (coupon.vendorId == 'ADMIN') {
                uniqueCodes.add(code);
                allCoupons.add(coupon);
              } else {
                // For vendor coupons, we might want to ensure they apply to this shop
                // In CheckoutScreenV2, we currently assume vendorId is enough
                uniqueCodes.add(code);
                allCoupons.add(coupon);
              }
            }
          }
        }

        setState(() {
          _vendorOffers = allCoupons;
        });

        Log.i('CheckoutScreen', '✅ Loaded ${allCoupons.length} unique active coupons (Vendor + Admin)');
      });
    } catch (e) {
      Log.e('CheckoutScreen', 'Error loading vendor coupons: $e');
      setState(() {
        _vendorOffers = [];
      });
    }
  }

  void _checkDeliveryAvailability() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) return;
    final firstItem = cart.items.values.first;
    final shopLat = firstItem.shopLat;
    final shopLng = firstItem.shopLng;
    final city = firstItem.city ?? '';

    // If no coordinates, can't determine — stay fail-closed (false)
    if (shopLat == null || shopLng == null) return;

    _deliverySubscription = _deliveryService
        .streamShopDeliveryStatus(
          shopId: firstItem.shopId,
          shopLat: shopLat,
          shopLng: shopLng,
          city: city,
          radiusKm: 10.0,
        )
        .listen((available) {
          if (mounted) setState(() => _deliveryAvailable = available);
        });
  }

  Future<void> _checkAddressDeliveryRadius(Map<String, dynamic> address) async {
    Log.i('CheckoutScreen', '🔍 [RadiusCheck] _checkAddressDeliveryRadius called');
    double? addrLat;
    double? addrLng;

    if (address['lat'] != null || address['latitude'] != null) {
      addrLat = (address['lat'] ?? address['latitude'] as num).toDouble();
      addrLng = (address['lng'] ?? address['longitude'] as num).toDouble();
      Log.i('CheckoutScreen', '🔍 [RadiusCheck] Using address coords: ($addrLat, $addrLng)');
    } else {
      final locProvider = Provider.of<LocationProvider>(context, listen: false);
      if (locProvider.currentPosition != null) {
        addrLat = locProvider.currentPosition!.latitude;
        addrLng = locProvider.currentPosition!.longitude;
        Log.i('CheckoutScreen', '🔍 [RadiusCheck] Using GPS coords: ($addrLat, $addrLng)');
      }
    }
    if (addrLat == null || addrLng == null) {
      Log.i('CheckoutScreen', '🔍 [RadiusCheck] No coordinates available, skipping');
      return;
    }

    final cart = Provider.of<CartProvider>(context, listen: false);
    final firstItem = cart.items.values.first;
    final shopLat = firstItem.shopLat;
    final shopLng = firstItem.shopLng;
    if (shopLat == null || shopLng == null) {
      Log.i('CheckoutScreen', '🔍 [RadiusCheck] No shop coordinates, skipping');
      return;
    }

    // Try Google Maps Directions API for actual road distance
    double distance;
    try {
      final directions = await GoogleMapsDirectionsService.getDirections(
        origin: LatLng(addrLat, addrLng),
        destination: LatLng(shopLat, shopLng),
      );
      if (directions != null && directions.distanceValue > 0) {
        distance = directions.distanceValue / 1000.0;
        Log.i('CheckoutScreen', '🔍 [RadiusCheck] Road distance: ${distance.toStringAsFixed(1)} km');
      } else {
        throw Exception('No directions result');
      }
    } catch (e) {
      Log.w('CheckoutScreen', '[RadiusCheck] Directions API failed, using Haversine: $e');
      distance = DeliveryFeeService.calculateDistance(
        userLat: addrLat,
        userLng: addrLng,
        shopLat: shopLat,
        shopLng: shopLng,
      );
        Log.i('CheckoutScreen', '🔍 [RadiusCheck] Haversine distance: ${distance.toStringAsFixed(1)} km');
    }

    try {
      final shopDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(firstItem.shopId)
          .get();
      final shopData = shopDoc.data();
      final deliveryRadius = shopData == null
          ? 15.0
          : ShopService.deliveryRadiusKm(shopData);
      Log.i('CheckoutScreen', '🔍 [RadiusCheck] Shop deliveryRadius: $deliveryRadius km');

      if (distance > deliveryRadius) {
        Log.i('CheckoutScreen', '🔍 [RadiusCheck] OUT OF RANGE! Showing error');
        if (mounted) {
          setState(() {
            _deliveryRadiusError =
                'Not delivered at this location '
                '(distance: ${distance.toStringAsFixed(1)} km, '
                'shop max: ${deliveryRadius.toStringAsFixed(0)} km).';
          });
        }
      } else {
        Log.i('CheckoutScreen', '🔍 [RadiusCheck] Within range');
        if (mounted) {
          setState(() => _deliveryRadiusError = null);
        }
      }
    } catch (e) {
      Log.w('CheckoutScreen', '[RadiusCheck] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    // Debug log
    Log.i('CheckoutScreen', '✅ CHECKOUT V2 BUILD RUNNING - Cart items: ${cart.items.length}');

    // Safe calculations (real-time from admin Dynamic Config)
    final rc = RuntimeConfigService.instance;
    final gstFraction = rc.gstEnabled ? rc.gstRate / 100 : 0.0;
    double subtotal = cart.totalAmount;
    double productGst = _isGstRegistered ? cart.totalGstAmount : 0.0;
    double platformFee = rc.platformFeeEnabled ? rc.platformCustomerFee : 0.0;
    double deliveryFee = _deliveryFee;

    // GST components (Delivery + Platform Profit) at configured GST rate
    double commission = cart.totalCommissionAmount;
    double deliveryGst = deliveryFee * gstFraction;
    double platformProfitGst = (platformFee + commission) * gstFraction;

    // TCS (Tax Collected at Source) from admin config
    // Empty `applicableOn` means the tax applies to ALL categories.
    final List<String> tcsCats = rc.tcsApplicableOn
        .whereType<String>()
        .map((c) => c.trim().toLowerCase())
        .toList();
    final bool tcsEnabled = rc.tcsEnabled &&
        subtotal >= rc.tcsThreshold &&
        (tcsCats.isEmpty ||
            cart.items.values.any(
                (i) => tcsCats.contains((i.category ?? '').toLowerCase())));
    double tcsAmount = tcsEnabled ? subtotal * (rc.tcsRate / 100) : 0.0;

    double totalGstAndTaxes = productGst + deliveryGst + platformProfitGst;
    double total =
        subtotal +
        deliveryFee +
        platformFee +
        totalGstAndTaxes +
        tcsAmount +
        _tipAmount -
        _couponDiscount;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF08090D),
      body: SafeArea(
        child: cart.items.isEmpty
            ? _buildEmptyState()
            : Column(
                children: [
                  _buildStickyHeader(cart),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 100),
                        child: Column(
                          children: [
                            CheckoutCartView(
                              cart: cart,
                              onAddMoreItems: _navigateToAddItems,
                              onItemQuantityChange: (item, delta) {
                                _updateItemQuantity(
                                  item.id,
                                  item.quantity + delta,
                                );
                              },
                              onDeliveryNoteTap: () => _showNoteBottomSheet(
                                title: 'Delivery Note',
                                hint:
                                    'Add instructions for delivery partner...',
                                controller: _deliveryNoteController,
                              ),
                              onShopNoteTap: () => _showNoteBottomSheet(
                                title: 'Note to Shop',
                                hint: 'Add instructions for shop...',
                                controller: _shopNoteController,
                              ),
                            ),
                            CheckoutAddressPicker(
                              deliveryEta: _estimatedDeliveryTime > 0
                                  ? 'Delivery in ${_estimatedDeliveryTime - 3}-${_estimatedDeliveryTime + 3} mins'
                                  : 'Delivery in 25-35 mins',
                              distance: _distance > 0 ? _distance : 2.4,
                              isUpdating: _isUpdatingDelivery,
                              selectedAddress: _selectedAddress,
                              settingsService: _settingsService,
                              onAddressSelected: (address) async {
                                setState(() {
                                  _selectedAddress = address;
                                  _deliveryRadiusError = null;
                                  _isUpdatingDelivery = true;
                                });
                                final addressId = address['id'] as String?;
                                if (addressId != null && addressId.isNotEmpty) {
                                  await _settingsService.selectAddress(
                                    addressId,
                                  );
                                }
                                await _calculateDeliveryFee(
                                  addressOverride: address,
                                );
                                await _checkAddressDeliveryRadius(address);
                                if (mounted) {
                                  setState(() => _isUpdatingDelivery = false);
                                }
                              },
                            ),
                            if (!_deliveryAvailable)
                              Container(
                                margin: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFE53935,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFE53935,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delivery_dining,
                                      color: Color(0xFFE53935),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Currently not delivering — no riders available',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFE53935),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_deliveryRadiusError != null)
                              Container(
                                margin: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFE53935,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFE53935,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_off_rounded,
                                      color: Color(0xFFE53935),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _deliveryRadiusError!,
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFE53935),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            CheckoutOrderSummary(
                              subtotal: subtotal,
                              deliveryFee: deliveryFee,
                              totalGstAndTaxes: totalGstAndTaxes,
                              platformFee: platformFee,
                              tcs: tcsAmount,
                              tipAmount: _tipAmount,
                              total: total,
                              couponDiscount: _couponDiscount,
                              appliedCouponCode: _appliedCouponCode,
                              appliedOffer: _appliedOffer,
                              savingsAmount: _realtimeSavings,
                              savingsNotifier: _savingsNotifier,
                              vendorOffers: _vendorOffers,
                              onShowSavingsBreakdown: _showSavingsBreakdown,
                              onRemoveCoupon: _removeVendorOffer,
                              onApplyCouponFromCard: _applyCouponFromCard,
                              couponController: _couponController,
                              onApplyManualCoupon: _applyManualCoupon,
                              onApplyVendorOffer: (offer) {
                                _applyVendorOffer(offer);
                              },
                              onTipSelected: (tip) {
                                setState(() {
                                  _tipAmount = tip;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildProceedToPaymentBar(subtotal, total),
                ],
              ),
      ),
    );
  }

  Widget _buildProceedToPaymentBar(double subtotal, double total) {
    const double minOrder = 99;
    final double shortfall = minOrder - subtotal;
    final bool meetsMinOrder = shortfall <= 0;
    final bool canProceed =
        !_isProcessing && _deliveryAvailable && _deliveryRadiusError == null && meetsMinOrder;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF08090D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFFF6A00).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6A00).withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!meetsMinOrder) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6A00).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF6A00).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_shopping_cart_rounded,
                        color: Color(0xFFFF6A00),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Add ₹${shortfall.ceil()} more to reach the ₹$minOrder minimum order',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFA1A1AA),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '₹${total.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: _buildProceedButton(total, canProceed, shortfall),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProceedButton(double total, bool canProceed, double shortfall) {
    final bool meetsMinOrder = shortfall <= 0;
    return GestureDetector(
      onTap: canProceed ? () => _handlePlaceOrder(total) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 58,
        decoration: BoxDecoration(
          gradient: canProceed
              ? const LinearGradient(
                  colors: [Color(0xFFFF5F00), Color(0xFFFF8A00)],
                )
              : LinearGradient(
                  colors: [
                    Colors.grey.withValues(alpha: 0.4),
                    Colors.grey.withValues(alpha: 0.2),
                  ],
                ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: canProceed
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF6A00).withValues(alpha: 0.5),
                    blurRadius: 18,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: _isProcessing
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Colors.white.withValues(
                        alpha: canProceed ? 1.0 : 0.4,
                      ),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        !meetsMinOrder
                            ? 'Add ₹${shortfall.ceil()} more'
                            : canProceed
                            ? 'Proceed to Payment'
                            : 'Checkout unavailable',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(
                            alpha: canProceed ? 1.0 : 0.4,
                          ),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (canProceed) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6A00).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF6A00).withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6A00).withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Text('🛒', style: TextStyle(fontSize: 64)),
            ),
            const SizedBox(height: 32),
            Text(
              'Your cart is empty',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add medicines to continue',
              style: GoogleFonts.poppins(
                color: const Color(0xFFA1A1AA),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6A00), Color(0xFFFF9500)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6A00).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Browse Medicines',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyHeader(CartProvider cart) {
    final firstItem = cart.items.values.firstOrNull;
    final shopName = firstItem?.shopName ?? 'Store';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF08090D),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF6A00).withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              if (!mounted) return;
              Navigator.pop(context);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shopName,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updateItemQuantity(String itemId, int newQuantity) {
    if (!mounted) return;

    final cart = Provider.of<CartProvider>(context, listen: false);

    if (newQuantity <= 0) {
      // Remove item with confirmation
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF14141C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Remove Item',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Do you want to remove this item from cart?',
            style: GoogleFonts.poppins(color: const Color(0xFFA1A1AA)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: const Color(0xFFA1A1AA)),
              ),
            ),
            TextButton(
              onPressed: () {
                cart.removeItem(itemId);
                Navigator.pop(dialogContext);
                _recalculateAll();
              },
              child: Text(
                'Remove',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFF6A00),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // Update quantity
    cart.setItemQuantity(itemId, newQuantity);

    // Recalculate all values
    _recalculateAll();
  }

  void _recalculateAll() {
    if (!mounted) return;

    // Recalculate delivery fee and savings
    _calculateDeliveryFee();
    _calculateSavings();
    _validateAppliedOffer();
  }

  void _validateAppliedOffer() {
    if (_appliedOffer == null) return;

    final cart = Provider.of<CartProvider>(context, listen: false);
    final subtotal = cart.totalAmount;
    final minOrder = _appliedOffer!.minOrderValue;

    if (subtotal < minOrder) {
      final deficit = minOrder - subtotal;
      final code = _appliedOffer!.code;

      setState(() {
        _appliedOffer = null;
        _appliedCouponCode = null;
        _couponDiscount = 0.0;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coupon $code removed. Add ₹${deficit.toInt()} more to reuse!',
          ),
          backgroundColor: const Color(0xFFFF6A00),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'ADD ITEMS',
            textColor: Colors.white,
            onPressed: () => _navigateToAddItems(),
          ),
        ),
      );
    } else {
      _applyVendorOffer(_appliedOffer!, silent: true);
    }
  }

  void _showNoteBottomSheet({
    required String title,
    required String hint,
    required TextEditingController controller,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF14141C),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFFFF6A00).withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Text input
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.6,
                  ),
                  maxLines: 5,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.poppins(
                      color: const Color(0xFFA1A1AA),
                      fontSize: 14,
                    ),
                    counterStyle: GoogleFonts.poppins(
                      color: const Color(0xFFA1A1AA),
                      fontSize: 11,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF171720),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),

            // Save button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$title saved'),
                        backgroundColor: const Color(0xFF22C55E),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6A00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyCouponFromCard(CouponModel coupon) {
    if (coupon.code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid coupon'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    _applyVendorOffer(coupon);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Coupon ${coupon.code} applied!'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _applyVendorOffer(CouponModel offer, {bool silent = false}) {
    if (!mounted) return;

    final cart = Provider.of<CartProvider>(context, listen: false);
    final subtotal = cart.totalAmount;

    double discount = offer.calculateDiscount(subtotal);
    if (offer.type == CouponType.freeDelivery) {
      discount = _deliveryFee;
    }

    if (offer.id != null) {
      CouponService.trackClick(offer.id!);
    }

    setState(() {
      _appliedOffer = offer;
      _appliedCouponCode = offer.code;
      _couponDiscount = discount;
    });

    if (silent) return;

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔥 Offer Applied! ₹${discount.toInt()} OFF'),
        backgroundColor: const Color(0xFFFF6A00),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _removeVendorOffer() {
    if (!mounted) return;

    setState(() {
      _appliedOffer = null;
      _appliedCouponCode = null;
      _couponDiscount = 0.0;
    });
  }

  void _applyManualCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final matchingCoupon = _vendorOffers
        .where((c) => c.code == code)
        .firstOrNull;

    if (matchingCoupon != null) {
      _applyCouponFromCard(matchingCoupon);
      _couponController.clear();
      FocusScope.of(context).unfocus();
    } else {
      try {
        final cart = Provider.of<CartProvider>(context, listen: false);
        if (cart.items.isEmpty) return;

        final vendorId = cart.items.values.first.vendorId;
        if (vendorId == null) {
          _showInvalidCouponError(code);
          return;
        }

        final result = await CouponService.applyCoupon(
          code: code,
          vendorId: vendorId,
          orderAmount: cart.totalAmount,
          deliveryFee: _deliveryFee,
          userId: FirebaseAuth.instance.currentUser?.uid,
          appliesTo: CouponModel.scopeMarketplace,
        );

        if (result.success) {
          if (result.coupon?.id != null) {
            CouponService.trackClick(result.coupon!.id!);
          }
          _applyCouponFromCard(result.coupon!);
          _couponController.clear();
          FocusScope.of(context).unfocus();
        } else {
          _showInvalidCouponError(result.error ?? code);
        }
      } catch (e) {
        Log.e('CheckoutScreen', 'Error applying coupon: $e');
        _showInvalidCouponError(code);
      }
    }
  }

  void _showInvalidCouponError(String code) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invalid coupon code: $code'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handlePlaceOrder(double total) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final double itemTotal = cart.totalAmount;
    if (itemTotal < 99) {
      final shortfall = (99 - itemTotal).ceil();
      _showError('Minimum order is ₹99 on item total. Add ₹$shortfall more to continue.');
      return;
    }

    if (_selectedAddress == null) {
      _showError('Please select delivery address');
      return;
    }

    // Validate delivery radius before proceeding
    try {
      if (!mounted) return;
      final cart = Provider.of<CartProvider>(context, listen: false);
      final firstItem = cart.items.values.first;
      final shopLat = firstItem.shopLat;
      final shopLng = firstItem.shopLng;

      // Extract address coordinates with GPS fallback
      final loc = Provider.of<LocationProvider>(context, listen: false);
      double? addrLat;
      double? addrLng;
      if (_selectedAddress?['lat'] != null) {
        addrLat = (_selectedAddress!['lat'] as num).toDouble();
        addrLng = (_selectedAddress!['lng'] as num).toDouble();
      } else if (loc.currentPosition != null) {
        addrLat = loc.currentPosition!.latitude;
        addrLng = loc.currentPosition!.longitude;
        Log.i('CheckoutScreen', '📍 [PlaceOrder] Using GPS fallback for radius check');
      }

      if (shopLat != null &&
          shopLng != null &&
          addrLat != null &&
          addrLng != null) {
        // Try Google Maps Directions API for actual road distance
        double actualDistance;
        try {
          final directions = await GoogleMapsDirectionsService.getDirections(
            origin: LatLng(addrLat, addrLng),
            destination: LatLng(shopLat, shopLng),
          );
          if (directions != null && directions.distanceValue > 0) {
            actualDistance = directions.distanceValue / 1000.0;
              Log.i('CheckoutScreen', '📍 [PlaceOrder] Road distance: ${actualDistance.toStringAsFixed(1)} km');
          } else {
            throw Exception('No directions result');
          }
        } catch (e) {
          Log.w('CheckoutScreen', '[PlaceOrder] Directions API failed, using Haversine: $e');
          actualDistance = DeliveryFeeService.calculateDistance(
            userLat: addrLat,
            userLng: addrLng,
            shopLat: shopLat,
            shopLng: shopLng,
          );
        }

        // Fetch the shop's delivery radius
        final shopDoc = await FirebaseFirestore.instance
            .collection('shops')
            .doc(firstItem.shopId)
            .get();
        final shopData = shopDoc.data();
        final deliveryRadius = shopData == null
            ? 15.0
            : ShopService.deliveryRadiusKm(shopData);

        if (actualDistance > deliveryRadius) {
          _showError(
            'Not delivered at this location '
            '(distance: ${actualDistance.toStringAsFixed(1)} km, '
            'shop max: ${deliveryRadius.toStringAsFixed(0)} km).',
          );
          return;
        }
      } else {
        Log.w('CheckoutScreen', '[Checkout] Cannot validate delivery radius — missing coordinates');
      }
    } catch (e) {
      // If we can't validate and distance looks large, block to be safe
      Log.w('CheckoutScreen', '[Checkout] Delivery radius validation error: $e');
      if (_distance > 50.0) {
        _showError(
          'Unable to verify delivery for this address. '
          'Please try a closer location.',
        );
        return;
      }
    }

    HapticFeedback.mediumImpact();

    await _openPremiumPayment(total);
  }

  /// Opens the custom premium payment screen. The screen owns the Razorpay
  /// flow and pops a [PaymentResult]; here we place the order accordingly.
  Future<void> _openPremiumPayment(double total) async {
    if (!mounted) return;

    final cart = Provider.of<CartProvider>(context, listen: false);
    final firstItem = cart.items.values.first;
    final currentUser = FirebaseAuth.instance.currentUser;

    final PaymentResult? result = await Navigator.push<PaymentResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumPaymentScreen(
          total: total,
          shopName: firstItem.shopName,
          description: 'Order from ${firstItem.shopName}',
          customerPhone:
              currentUser?.phoneNumber ?? _selectedAddress?['phone'] ?? '',
          customerEmail: currentUser?.email,
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (result.methodType == PaymentMethodType.cod) {
      _paymentMethod = 'COD';
      await _placeOrderCOD(total);
      return;
    }

    if (!result.success) {
      AnalyticsEventService.log('payment_failed', props: {
        'method': result.methodType.wireName,
        'amount': total,
        'reason': result.message ?? '',
      });
      if (result.message != null) _showError(result.message!);
      return;
    }

    _paymentMethod = result.methodType.wireName;
    setState(() => _isProcessing = true);

    try {
      AnalyticsEventService.log('payment_success', props: {
        'method': _paymentMethod,
        'amount': total,
        'paymentId': result.paymentId ?? '',
      });
      final orderId = await _placeOrder(
        paymentId: result.paymentId,
        razorpayOrderId: result.orderId,
        paymentStatus: 'paid',
        total: total,
      );

      if (!mounted) return;
      _clearCartAndNavigate(
        orderId,
        _paymentMethod,
        total,
        firstItem.shopName,
      );
    } catch (e) {
      Log.e('CheckoutScreen', '[Payment] Order placement failed: $e');
      _showError('Payment successful but order failed. Contact support with Payment ID: ${result.paymentId}');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _placeOrderCOD(double total) async {
    /*
    // Check if shop is still open
    final shopOpenCheck = await _checkShopStatusBeforeOrder();
    if (!shopOpenCheck) {
      return;
    }
    */

    Log.i('CheckoutScreen', '🚀 [Checkout] Navigating to PaymentProcessingScreen...');

    try {
      // Navigate to payment processing screen
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentProcessingScreen(
            total: total,
            shopName: Provider.of<CartProvider>(
              context,
              listen: false,
            ).currentShopName,
            paymentMethod: 'COD',
            onCancel: () {
              Log.e('CheckoutScreen', '[Checkout] Order cancelled during processing');
              Navigator.pop(context);
              setState(() => _isProcessing = false);
            },
            onComplete: () async {
              Log.i('CheckoutScreen', '✅ [Checkout] Processing complete, creating order...');
              setState(() => _isProcessing = true);

              try {
                final cart = Provider.of<CartProvider>(context, listen: false);
                final firstItem = cart.items.values.first;

                Log.i('CheckoutScreen', '📝 [Checkout] Placing COD order...');
                Log.i('CheckoutScreen', '📝 [Checkout] Shop ID: ${firstItem.shopId}');
                Log.i('CheckoutScreen', '📝 [Checkout] Vendor ID: ${firstItem.vendorId}');
                Log.i('CheckoutScreen', '📝 [Checkout] Items: ${cart.items.length}');
                Log.i('CheckoutScreen', '📝 [Checkout] Total: ₹$total');

                final orderId = await _placeOrder(
                  paymentStatus: 'pending_cod',
                  total: total,
                );

                Log.i('CheckoutScreen', '✅ [Checkout] Order placed successfully: $orderId');

                // Small delay to ensure order is fully written to Firestore
                await Future.delayed(const Duration(milliseconds: 300));

                _clearCartAndNavigate(
                  orderId,
                  'COD',
                  total,
                  firstItem.shopName,
                );
              } catch (e, stackTrace) {
                Log.e('CheckoutScreen', '[Checkout] Failed to place order: $e');
                Log.e('CheckoutScreen', '[Checkout] Stack trace: $stackTrace');
                _showError('Failed to place order: ${e.toString()}');
                Navigator.pop(context); // Close processing screen
                setState(() => _isProcessing = false);
              }
            },
          ),
        ),
      );
    } catch (e) {
      Log.e('CheckoutScreen', '[Checkout] Error in COD flow: $e');
      _showError('Failed to place order');
      setState(() => _isProcessing = false);
    }
  }

  Future<String> _placeOrder({
    String? paymentId,
    String? razorpayOrderId,
    required String paymentStatus,
    required double total,
  }) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final firstItem = cart.items.values.first;
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final rc = RuntimeConfigService.instance;
    final double platformFee =
        rc.platformFeeEnabled ? rc.platformCustomerFee : 0.0;
    final double gstFraction = rc.gstEnabled ? rc.gstRate / 100 : 0.0;

    // Recalculate components for backend consistency (real-time config)
    double subtotal = cart.totalAmount;
    double productGst = _isGstRegistered ? cart.totalGstAmount : 0.0;
    double deliveryFee = _deliveryFee;
    double commission = cart.totalCommissionAmount;
    double deliveryGst = deliveryFee * gstFraction;
    double platformProfitGst = (platformFee + commission) * gstFraction;
    double totalGstAndTaxes = productGst + deliveryGst + platformProfitGst;

    // TCS from admin config
    // Empty `applicableOn` means the tax applies to ALL categories.
    final List<String> tcsCats = rc.tcsApplicableOn
        .whereType<String>()
        .map((c) => c.trim().toLowerCase())
        .toList();
    final bool tcsEnabled = rc.tcsEnabled &&
        subtotal >= rc.tcsThreshold &&
        (tcsCats.isEmpty ||
            cart.items.values.any(
                (i) => tcsCats.contains((i.category ?? '').toLowerCase())));
    final double tcsAmount = tcsEnabled ? subtotal * (rc.tcsRate / 100) : 0.0;

    // Extract customer details from selected address
    final String? addressName =
        (_selectedAddress?['name']?.toString() ?? '').trim().isNotEmpty
            ? _selectedAddress!['name'].toString().trim()
            : null;
    final String? authName =
        (FirebaseAuth.instance.currentUser?.displayName ?? '').trim().isNotEmpty
            ? FirebaseAuth.instance.currentUser!.displayName!.trim()
            : null;
    String customerName = addressName ?? authName ?? 'Customer';
    if (addressName == null && authName == null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
            .get();
        final userName = (userDoc.data()?['name']?.toString() ?? '').trim();
        if (userName.isNotEmpty) customerName = userName;
      } catch (_) {
        // keep 'Customer' fallback
      }
    }
    final String customerPhone =
        _selectedAddress?['phone']?.toString() ??
        FirebaseAuth.instance.currentUser?.phoneNumber ??
        '';
    // Extract customer coordinates with GPS fallback
    final double? customerLat;
    final double? customerLng;
    if (_selectedAddress?['lat'] != null) {
      customerLat = (_selectedAddress!['lat'] as num).toDouble();
      customerLng = (_selectedAddress!['lng'] as num).toDouble();
    } else {
      final loc = Provider.of<LocationProvider>(context, listen: false);
      customerLat = loc.currentPosition?.latitude;
      customerLng = loc.currentPosition?.longitude;
      if (customerLat != null) {
        Log.i('CheckoutScreen', '📍 [_placeOrder] Using GPS fallback for customer coords');
      }
    }

    return await orderProvider.createOrder(
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      shopId: firstItem.shopId,
      vendorId: firstItem.vendorId,
      shopName: firstItem.shopName,
      items: cart.items.values
          .map(
            (i) => {
              'productId': i.id,
              'name': i.name,
              'price': i.price.toDouble(),
              'qty': i.quantity,
              'category': i.category,
            },
          )
          .toList(),
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      gst: totalGstAndTaxes,
      platformFee: platformFee,
      tcs: tcsAmount,
      discount: _couponDiscount,
      tip: _tipAmount,
      total: total,
      paymentMethod: _paymentMethod,
      paymentStatus: paymentStatus,
      paymentId: paymentId,
      razorpayOrderId: razorpayOrderId,
      address: _selectedAddress,
      customerName: customerName,
      customerPhone: customerPhone,
      customerLat: customerLat,
      customerLng: customerLng,
      specialRequest: _shopNoteController.text.trim(),
      deliveryNote: _deliveryNoteController.text.trim(),
      couponCode: _appliedCouponCode,
    );
  }

  void _clearCartAndNavigate(
    String orderId,
    String paymentMethod,
    double total,
    String shopName,
  ) {
    // Navigate FIRST before clearing cart to avoid empty cart flash
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessScreen(
          orderId: orderId,
          paymentMethod: paymentMethod.toLowerCase(),
          total: total.toInt(),
          shopName: shopName,
        ),
      ),
      (route) => false,
    );

    // Clear cart AFTER navigation (delayed to ensure smooth transition)
    Future.delayed(const Duration(milliseconds: 100), () async {
      final cart = Provider.of<CartProvider>(context, listen: false);

      // Record coupon usage if applicable
      if (_appliedOffer != null && _appliedOffer!.id != null) {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          try {
            await CouponService.recordUsage(_appliedOffer!.id!, userId);
            Log.i('CheckoutScreen', '✅ Coupon usage recorded for ${_appliedOffer!.code}');
          } catch (e) {
            Log.e('CheckoutScreen', 'Failed to record coupon usage: $e');
          }
        }
      }

      cart.clear();
      Log.i('CheckoutScreen', '🗑️ [Cart] Cleared after navigation to success screen');
    });
  }

  void _navigateToAddItems() {
    if (!mounted) return;

    final cart = Provider.of<CartProvider>(context, listen: false);

    if (cart.items.isEmpty || cart.currentShopId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items in cart'),
          backgroundColor: Color(0xFFFF6A00),
        ),
      );
      return;
    }

    final shopData = {
      'id': cart.currentShopId,
      'name': cart.currentShopName,
      'category': '',
      'rating': 0.0,
      'eta': '',
      'open': true,
    };

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ShopDetailScreen(shop: shopData)),
    );
  }

  void _showSavingsBreakdown() {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1F),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Text(
                'How You Saved Money',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(color: Color(0xFFA1A1AA), height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                children: [
                  // Total savings summary
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF13261A), Color(0xFF101A14)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TOTAL SAVINGS',
                          style: GoogleFonts.orbitron(
                            color: const Color(0xFF22C55E),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${(_savingsBreakdown?['totalSavings'] ?? 0).toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF22C55E),
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fuel + Parking saved today',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFA1A1AA),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Fuel Cost Saved
                  _savingsDetailCard(
                    '⛽',
                    'Fuel Cost Saved',
                    '₹${(_savingsBreakdown?['fuelCost'] ?? 0).toStringAsFixed(0)}',
                    '${(_savingsBreakdown?['roundTripDistance'] ?? 0).toStringAsFixed(1)} km round trip • ${(_savingsBreakdown?['mileage'] ?? 12).toStringAsFixed(0)} km/l • ₹${(_savingsBreakdown?['fuelPrice'] ?? 103).toStringAsFixed(0)}/L',
                  ),
                  const SizedBox(height: 12),

                  // Parking Avoided
                  _savingsDetailCard(
                    '🅿️',
                    'Parking Avoided',
                    '₹${(_savingsBreakdown?['parkingCost'] ?? 0).toStringAsFixed(0)}',
                    'Estimated parking charges at destination',
                  ),
                  const SizedBox(height: 12),

                  // Distance Avoided
                  _savingsDetailCard(
                    '🚗',
                    'Distance Avoided',
                    '${(_savingsBreakdown?['roundTripDistance'] ?? 0).toStringAsFixed(1)} km',
                    'Round trip travel saved (to shop & back)',
                  ),
                  const SizedBox(height: 12),

                  // Time Saved
                  _savingsDetailCard(
                    '⏱️',
                    'Time Saved',
                    '${(_savingsBreakdown?['timeSaved'] ?? 0)} mins',
                    'No travel or shopping time needed',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savingsDetailCard(
    String emoji,
    String title,
    String value,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14141C).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6A00).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFA1A1AA),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: const Color(0xFF22C55E),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
