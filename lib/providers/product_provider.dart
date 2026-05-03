import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Stream products for a specific shop (flat structure, no orderBy)
  Stream<List<Map<String, dynamic>>> streamShopProducts(String shopId) {
    if (shopId.isEmpty) {
      return Stream.error('shopId cannot be empty');
    }

    return _firestore
        .collection('products')
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Stream all products for a shop including unavailable
  Stream<List<Map<String, dynamic>>> streamAllShopProducts(String shopId) {
    if (shopId.isEmpty) {
      return Stream.error('shopId cannot be empty');
    }

    return _firestore
        .collection('products')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}