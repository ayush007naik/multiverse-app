import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class BrandingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🗂️ Categories
  Stream<List<Map<String, dynamic>>> streamCategories() {
    return _firestore
        .collection('metadata')
        .doc('branding')
        .collection('categories')
        .orderBy('priority', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // 🎁 Offers
  Stream<List<Map<String, dynamic>>> streamOffers() {
    return _firestore
        .collection('metadata')
        .doc('branding')
        .collection('offers')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // 🏡 Real Estate
  Stream<List<Map<String, dynamic>>> streamProperties() {
    return _firestore
        .collection('properties')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  // Helper to initialize some default data if needed
  Future<void> initializeDefaultMetadata() async {
    final brandingDoc = _firestore.collection('metadata').doc('branding');
    
    // Check if categories exist
    final categoriesSnapshot = await brandingDoc.collection('categories').limit(1).get();
    if (categoriesSnapshot.docs.isEmpty) {
      final defaultCategories = [
        {'icon': '🍔', 'name': 'Food', 'priority': 100},
        {'icon': '🛒', 'name': 'Grocery', 'priority': 90},
        {'icon': '💊', 'name': 'Medicines', 'priority': 80},
        {'icon': '👗', 'name': 'Fashion', 'priority': 70},
        {'icon': '💄', 'name': 'Beauty', 'priority': 60},
        {'icon': '📱', 'name': 'Electronics', 'priority': 50},
        {'icon': '🛋️', 'name': 'Furniture', 'priority': 40},
        {'icon': '📚', 'name': 'Stationery', 'priority': 30},
        {'icon': '🛠️', 'name': 'Services', 'priority': 20},
        {'icon': '🎁', 'name': 'Gifts', 'priority': 15},
        {'icon': '🐾', 'name': 'Pet Care', 'priority': 10},
      ];
      for (var cat in defaultCategories) {
        await brandingDoc.collection('categories').add(cat);
      }
    }

    // FORCE UPDATE: Delete all old offers and recreate
    final offersSnapshot = await brandingDoc.collection('offers').get();
    
    // Delete old offers
    for (var doc in offersSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // Create fresh offers with updated data
    final defaultOffers = [
      {
        'title': '60% OFF on Selected Shops',
        'sub': 'Limited time deals on top stores',
        'color1': '0xFFFF4D4F',
        'color2': '0xFFCF1322',
        'tag': '🔥 Trending',
        'isActive': true,
      },
      {
        'title': 'FREE Delivery',
        'sub': 'Orders above ₹699',
        'color1': '0xFF6200EA',
        'color2': '0xFF2196F3',
        'isActive': true,
      },
    ];
    for (var offer in defaultOffers) {
      await brandingDoc.collection('offers').add(offer);
    }
    
    debugPrint('✅ Offers updated: ${defaultOffers.length} banners created');
  }
}
