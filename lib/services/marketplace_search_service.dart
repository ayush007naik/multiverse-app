import 'package:db_compat/db_compat.dart';
import '../core/logging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Marketplace Search Service
/// ONLY searches: shops, products, offers
/// DOES NOT search: services, movies, real estate
class MarketplaceSearchService {
  static final MarketplaceSearchService _instance =
      MarketplaceSearchService._internal();
  factory MarketplaceSearchService() => _instance;
  MarketplaceSearchService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _recentSearchesKey = 'marketplace_recent_searches';
  static const int _maxRecentSearches = 10;

  // ========== SEARCH METHODS ==========

  /// Search shops by name, category, city, area, or offers
  Future<List<Map<String, dynamic>>> searchShops(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final shopsSnapshot = await _db
          .collection('shops')
          .where('isActive', isEqualTo: true)
          .get();

      final results = <Map<String, dynamic>>[];
      final queryLower = query.toLowerCase().trim();

      for (final doc in shopsSnapshot.docs) {
        final data = doc.data();
        final shopId = doc.id;

        // Search in multiple fields
        final name = (data['name'] as String? ?? '').toLowerCase();
        final category = (data['category'] as String? ?? '').toLowerCase();
        final city = (data['city'] as String? ?? '').toLowerCase();
        final area = (data['area'] as String? ?? '').toLowerCase();
        final offer = (data['offer'] as String? ?? '').toLowerCase();
        final description = (data['description'] as String? ?? '')
            .toLowerCase();

        // Check if query matches any field (exact, substring, or fuzzy)
        if (name.contains(queryLower) ||
            category.contains(queryLower) ||
            city.contains(queryLower) ||
            area.contains(queryLower) ||
            offer.contains(queryLower) ||
            description.contains(queryLower) ||
            _isFuzzyMatch(queryLower, name) ||
            _isFuzzyMatch(queryLower, category)) {
          results.add({
            'type': 'shop',
            'id': shopId,
            ...data,
            'matchScore': _calculateMatchScore(queryLower, {
              'name': name,
              'category': category,
              'city': city,
              'area': area,
              'offer': offer,
            }),
          });
        }
      }

      // Sort by match score
      results.sort(
        (a, b) => (b['matchScore'] as int).compareTo(a['matchScore'] as int),
      );

      return results;
    } catch (e) {
      Log.e('MarketplaceSearchService', 'Error searching shops: $e');
      return [];
    }
  }

  /// Search products by name, description, category, or shop
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final productsSnapshot = await _db
          .collection('products')
          .where('isActive', isEqualTo: true)
          .get();

      final results = <Map<String, dynamic>>[];
      final queryLower = query.toLowerCase().trim();

      // Batch-fetch shop names to avoid N+1 queries
      final shopIdsToFetch = <String>{};
      for (final doc in productsSnapshot.docs) {
        final data = doc.data();
        final shopName = (data['shopName'] as String? ?? '');
        if (shopName.isEmpty && data['shopId'] != null) {
          shopIdsToFetch.add(data['shopId'] as String);
        }
      }
      final shopNames = <String, String>{};
      if (shopIdsToFetch.isNotEmpty) {
        final shopRefs = shopIdsToFetch
            .map((id) => _db.collection('shops').doc(id))
            .toList();
        final shopDocs = await Future.wait(shopRefs.map((ref) => ref.get()));
        for (final shopDoc in shopDocs) {
          if (shopDoc.exists) {
            shopNames[shopDoc.id] =
                shopDoc.data()?['name'] as String? ?? '';
          }
        }
      }

      for (final doc in productsSnapshot.docs) {
        final data = doc.data();
        final productId = doc.id;

        // Resolve shop name from batch-fetched cache
        String shopName = (data['shopName'] as String? ?? '');
        if (shopName.isEmpty && data['shopId'] != null) {
          shopName = shopNames[data['shopId'] as String] ?? '';
          data['shopName'] = shopName;
        }

        // Search in multiple fields
        final name = (data['name'] as String? ?? '').toLowerCase();
        final description = (data['description'] as String? ?? '')
            .toLowerCase();
        final category = (data['category'] as String? ?? '').toLowerCase();
        final shopNameLower = shopName.toLowerCase();
        final brand = (data['brand'] as String? ?? '').toLowerCase();

        // Check if query matches any field (exact, substring, or fuzzy)
        if (name.contains(queryLower) ||
            description.contains(queryLower) ||
            category.contains(queryLower) ||
            shopNameLower.contains(queryLower) ||
            brand.contains(queryLower) ||
            _isFuzzyMatch(queryLower, name) ||
            _isFuzzyMatch(queryLower, category) ||
            _isFuzzyMatch(queryLower, shopNameLower) ||
            _isFuzzyMatch(queryLower, brand)) {
          results.add({
            'type': 'product',
            'id': productId,
            ...data,
            'matchScore': _calculateMatchScore(queryLower, {
              'name': name,
              'description': description,
              'category': category,
              'shopName': shopNameLower,
              'brand': brand,
            }),
          });
        }
      }

      // Sort by match score
      results.sort(
        (a, b) => (b['matchScore'] as int).compareTo(a['matchScore'] as int),
      );

      return results;
    } catch (e) {
      Log.e('MarketplaceSearchService', 'Error searching products: $e');
      return [];
    }
  }

  /// Search offers by title, description, or shop
  Future<List<Map<String, dynamic>>> searchOffers(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final offersSnapshot = await _db
          .collection('offers')
          .where('isActive', isEqualTo: true)
          .get();

      final results = <Map<String, dynamic>>[];
      final queryLower = query.toLowerCase().trim();

      for (final doc in offersSnapshot.docs) {
        final data = doc.data();
        final offerId = doc.id;

        // Search in multiple fields
        final title = (data['title'] as String? ?? '').toLowerCase();
        final description = (data['description'] as String? ?? '')
            .toLowerCase();
        final shopName = (data['shopName'] as String? ?? '').toLowerCase();
        final category = (data['category'] as String? ?? '').toLowerCase();
        final offerType = (data['offerType'] as String? ?? '').toLowerCase();

        // Check if query matches any field (exact, substring, or fuzzy)
        if (title.contains(queryLower) ||
            description.contains(queryLower) ||
            shopName.contains(queryLower) ||
            category.contains(queryLower) ||
            offerType.contains(queryLower) ||
            _isFuzzyMatch(queryLower, title) ||
            _isFuzzyMatch(queryLower, category)) {
          results.add({
            'type': 'offer',
            'id': offerId,
            ...data,
            'matchScore': _calculateMatchScore(queryLower, {
              'title': title,
              'description': description,
              'shopName': shopName,
              'category': category,
            }),
          });
        }
      }

      // Sort by match score
      results.sort(
        (a, b) => (b['matchScore'] as int).compareTo(a['matchScore'] as int),
      );

      return results;
    } catch (e) {
      Log.e('MarketplaceSearchService', 'Error searching offers: $e');
      return [];
    }
  }

  /// Combined search - searches shops, products, and offers
  Future<Map<String, List<Map<String, dynamic>>>> searchAll(
    String query,
  ) async {
    if (query.trim().isEmpty) {
      return {'shops': [], 'products': [], 'offers': []};
    }

    // Save to recent searches
    await saveRecentSearch(query);

    // Run all searches in parallel
    final results = await Future.wait([
      searchShops(query),
      searchProducts(query),
      searchOffers(query),
    ]);

    return {'shops': results[0], 'products': results[1], 'offers': results[2]};
  }

  // ========== MATCH SCORE CALCULATION ==========

  /// Simple subsequence fuzzy match
  /// Returns true if all characters in query appear in target in order
  bool _isFuzzyMatch(String query, String target) {
    if (query.isEmpty) return true;
    if (query.length > target.length) return false;

    // For very short queries, require exact or startsWith (already handled by contains)
    // to avoid too many false positives
    if (query.length < 2) return false;

    int queryIdx = 0;
    int targetIdx = 0;

    while (queryIdx < query.length && targetIdx < target.length) {
      if (query[queryIdx] == target[targetIdx]) {
        queryIdx++;
      }
      targetIdx++;
    }

    return queryIdx == query.length;
  }

  /// Calculate relevance score for better ranking
  int _calculateMatchScore(String query, Map<String, String> fields) {
    int score = 0;

    // Exact match in name/title gets highest priority
    final nameField = fields['name'] ?? fields['title'] ?? '';
    if (nameField == query) {
      score += 1000;
    } else if (nameField.startsWith(query)) {
      score += 500;
    } else if (nameField.contains(query)) {
      score += 200;
    } else if (_isFuzzyMatch(query, nameField)) {
      // Fuzzy match score (lower than substring match)
      score += 50;
    }

    // Category match
    final category = fields['category'] ?? '';
    if (category == query) {
      score += 300;
    } else if (category.contains(query)) {
      score += 100;
    } else if (_isFuzzyMatch(query, category)) {
      score += 25;
    }

    // Shop name match
    final shopName = fields['shopName'] ?? '';
    if (shopName.contains(query)) {
      score += 150;
    } else if (_isFuzzyMatch(query, shopName)) {
      score += 40;
    }

    // Description match (lower priority)
    final description = fields['description'] ?? '';
    if (description.contains(query)) {
      score += 50;
    }

    // City/Area match
    final city = fields['city'] ?? '';
    final area = fields['area'] ?? '';
    if (city.contains(query) || area.contains(query)) {
      score += 75;
    }

    // Offer match
    final offer = fields['offer'] ?? '';
    if (offer.contains(query)) {
      score += 125;
    }

    return score;
  }

  // ========== RECENT SEARCHES ==========

  /// Save search to recent searches
  Future<void> saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final recentSearches = await getRecentSearches();

      // Remove if already exists
      recentSearches.remove(query);

      // Add to front
      recentSearches.insert(0, query);

      // Keep only last N searches
      if (recentSearches.length > _maxRecentSearches) {
        recentSearches.removeRange(_maxRecentSearches, recentSearches.length);
      }

      // Save
      await prefs.setString(_recentSearchesKey, jsonEncode(recentSearches));
    } catch (e) {
      Log.e('MarketplaceSearchService', 'Error saving recent search: $e');
    }
  }

  /// Get recent searches
  Future<List<String>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_recentSearchesKey);

      if (data == null || data.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(data);
      return decoded.cast<String>();
    } catch (e) {
      Log.e('MarketplaceSearchService', 'Error getting recent searches: $e');
      return [];
    }
  }

  /// Clear all recent searches
  Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (e) {
      Log.e('MarketplaceSearchService', 'Error clearing recent searches: $e');
    }
  }

  /// Delete a specific recent search
  Future<void> deleteRecentSearch(String query) async {
    try {
      final recentSearches = await getRecentSearches();
      recentSearches.remove(query);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_recentSearchesKey, jsonEncode(recentSearches));
    } catch (e) {
      Log.e('MarketplaceSearchService', 'Error deleting recent search: $e');
    }
  }

  // ========== TRENDING PRODUCTS ==========

  /// Get trending products (most popular searches)
  Future<List<String>> getTrendingSearches() async {
    // This can be enhanced with actual search analytics
    // For now, returning sample trending items
    return [
      'iPhone',
      'Milk',
      'Grocery',
      'Electronics',
      'Pharmacy',
      'Fashion',
      'Free Delivery',
      'Discount',
    ];
  }

  // ========== SEARCH SUGGESTIONS ==========

  /// Get search suggestions based on query
  Future<List<String>> getSuggestions(String query) async {
    if (query.trim().isEmpty) {
      return await getTrendingSearches();
    }

    final suggestions = <String>{};

    try {
      // Get shops suggestions
      final shops = await searchShops(query);
      for (final shop in shops.take(3)) {
        suggestions.add(shop['name'] as String);
      }

      // Get products suggestions
      final products = await searchProducts(query);
      for (final product in products.take(3)) {
        suggestions.add(product['name'] as String);
      }

      // Get offers suggestions
      final offers = await searchOffers(query);
      for (final offer in offers.take(2)) {
        suggestions.add(offer['title'] as String);
      }

      return suggestions.take(10).toList();
    } catch (e) {
      Log.e('MarketplaceSearchService', 'Error getting suggestions: $e');
      return [];
    }
  }
}
