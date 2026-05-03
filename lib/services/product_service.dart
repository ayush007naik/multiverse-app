import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save product to root 'products' collection with shopId field
  Future<void> addProduct({
    required String shopId,
    required String vendorId,
    required String name,
    required double price,
    required String description,
    required String category,
    required String imageUrl,
    bool isAvailable = true,
  }) async {
    await _firestore.collection('products').add({
      'shopId': shopId,
      'vendorId': vendorId,
      'name': name,
      'price': price,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'isActive': isAvailable,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream products for a specific shop (STANDARDIZED - NO ORDERBY)
  /// Uses simple where filters that don't require composite indexes
  Stream<QuerySnapshot<Map<String, dynamic>>> streamShopProducts(String shopId) {
    if (shopId.isEmpty) {
      return Stream.error('shopId cannot be empty');
    }

    // STANDARDIZED QUERY: Single collection, simple where filters
    // This query does NOT require composite indexes
    return _firestore
        .collection('products')
        .where('shopId', isEqualTo: shopId)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  /// Stream all products for a shop including unavailable (STANDARDIZED)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllShopProducts(String shopId) {
    if (shopId.isEmpty) {
      return Stream.error('shopId cannot be empty');
    }

    // STANDARDIZED QUERY: Single where filter, no orderBy
    return _firestore
        .collection('products')
        .where('shopId', isEqualTo: shopId)
        .snapshots();
  }

  /// Stream vendor products across all their shops (STANDARDIZED - NO ORDERBY)
  /// Uses simple where filter that doesn't require composite indexes
  Stream<QuerySnapshot<Map<String, dynamic>>> streamVendorProducts(String vendorId) {
    if (vendorId.isEmpty) {
      return Stream.error('vendorId cannot be empty');
    }

    // STANDARDIZED QUERY: Single collection, simple where filter
    // This query does NOT require composite indexes
    return _firestore
        .collection('products')
        .where('vendorId', isEqualTo: vendorId)
        .snapshots();
  }

  /// Delete product from root 'products' collection
  Future<void> deleteProduct(String shopId, String productId) async {
    if (shopId.isEmpty || productId.isEmpty) {
      throw Exception('shopId and productId cannot be empty');
    }

    await _firestore
        .collection('products')
        .doc(productId)
        .delete();
  }

  /// Toggle product availability in root 'products' collection
  Future<void> toggleProductStatus(String shopId, String productId, bool isAvailable) async {
    if (shopId.isEmpty || productId.isEmpty) {
      throw Exception('shopId and productId cannot be empty');
    }

    await _firestore
        .collection('products')
        .doc(productId)
        .update({
      'isActive': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Check if error is a missing Firestore index error
  static bool isMissingIndexError(dynamic error) {
    if (error == null) return false;
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('index') && 
           (errorStr.contains('create') || errorStr.contains('missing'));
  }

  /// Extract index creation URL from Firestore error
  static String? extractIndexCreationUrl(dynamic error) {
    if (error == null) return null;
    final errorStr = error.toString();
    
    // Look for Firestore index creation URL pattern
    final regex = RegExp(r'https://console\.firebase\.google\.com[^"]+');
    final match = regex.firstMatch(errorStr);
    
    return match?.group(0);
  }

  /// Show dialog to help user create missing Firestore index
  static void showIndexCreationDialog({
    required dynamic context,
    required dynamic error,
    required VoidCallback onRetry,
  }) {
    // This method is intentionally left as a no-op
    // The vendor_dashboard.dart handles the dialog directly
    // This method exists for API compatibility
  }
}