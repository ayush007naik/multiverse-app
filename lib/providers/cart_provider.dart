import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/cart_model.dart';
import '../utils/delivery_fee_calculator.dart';

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  String _currentShopId = '';
  String _currentShopName = '';

  Map<String, CartItem> get items => {..._items};
  int get itemCount => _items.length;
  String get currentShopId => _currentShopId;
  String get currentShopName => _currentShopName;
  String get deliveryType => DeliveryFeeCalculator.detectDeliveryType(
    _items.values.map((item) => {'deliveryType': item.deliveryType}).toList(),
  );
  String get vehicle =>
      DeliveryFeeCalculator.vehicleForDeliveryType(deliveryType);

  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  int get totalItems {
    int total = 0;
    _items.forEach((key, cartItem) {
      total += cartItem.quantity;
    });
    return total;
  }

  CartProvider() {
    _loadCartFromStorage();
  }

  Future<void> _loadCartFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');
      final shopId = prefs.getString('shop_id') ?? '';
      final shopName = prefs.getString('shop_name') ?? '';

      if (cartJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(cartJson);
        _items.clear();
        decoded.forEach((key, value) {
          _items[key] = CartItem.fromMap(value as Map<String, dynamic>);
        });
        _currentShopId = shopId;
        _currentShopName = shopName;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  Future<void> _saveCartToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> itemsMap = {};
      _items.forEach((key, value) {
        itemsMap[key] = value.toMap();
      });
      await prefs.setString('cart_items', jsonEncode(itemsMap));
      await prefs.setString('shop_id', _currentShopId);
      await prefs.setString('shop_name', _currentShopName);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }

  void addItem({
    required String productId,
    required String name,
    required double price,
    required String image,
    required String shopId,
    required String shopName,
    String? vendorId,
    double? shopLat,
    double? shopLng,
    String deliveryType = DeliveryFeeCalculator.normalDeliveryType,
    int quantity = 1,
  }) {
    _currentShopId = shopId;
    _currentShopName = shopName;

    if (_items.containsKey(productId)) {
      _items.update(
        productId,
        (existingItem) => CartItem(
          id: existingItem.id,
          name: existingItem.name,
          price: existingItem.price,
          quantity: existingItem.quantity + quantity,
          image: existingItem.image,
          shopId: existingItem.shopId,
          shopName: existingItem.shopName,
          vendorId: existingItem.vendorId,
          shopLat: existingItem.shopLat,
          shopLng: existingItem.shopLng,
          deliveryType: existingItem.deliveryType,
        ),
      );
    } else {
      _items.putIfAbsent(
        productId,
        () => CartItem(
          id: productId,
          name: name,
          price: price,
          quantity: quantity,
          image: image,
          shopId: shopId,
          shopName: shopName,
          vendorId: vendorId,
          shopLat: shopLat,
          shopLng: shopLng,
          deliveryType: DeliveryFeeCalculator.normalizeDeliveryType(
            deliveryType,
          ),
        ),
      );
    }
    _saveCartToStorage();
    notifyListeners();
  }

  void setItemQuantity(String productId, int quantity) {
    if (!_items.containsKey(productId)) return;
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }
    final item = _items[productId]!;
    _items[productId] = CartItem(
      id: item.id,
      name: item.name,
      price: item.price,
      quantity: quantity,
      image: item.image,
      shopId: item.shopId,
      shopName: item.shopName,
      vendorId: item.vendorId,
      shopLat: item.shopLat,
      shopLng: item.shopLng,
      deliveryType: item.deliveryType,
    );
    _saveCartToStorage();
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    if (_items.isEmpty) {
      _currentShopId = '';
      _currentShopName = '';
    }
    _saveCartToStorage();
    notifyListeners();
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existingItem) => CartItem(
          id: existingItem.id,
          name: existingItem.name,
          price: existingItem.price,
          quantity: existingItem.quantity - 1,
          image: existingItem.image,
          shopId: existingItem.shopId,
          shopName: existingItem.shopName,
          vendorId: existingItem.vendorId,
          shopLat: existingItem.shopLat,
          shopLng: existingItem.shopLng,
          deliveryType: existingItem.deliveryType,
        ),
      );
    } else {
      _items.remove(productId);
    }
    _saveCartToStorage();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _currentShopId = '';
    _currentShopName = '';
    _saveCartToStorage();
    notifyListeners();
  }
}
