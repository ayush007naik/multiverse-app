import 'package:flutter/material.dart';
import 'shop_detail_screen.dart';
import 'category_products_screen.dart';
import '../widgets/category_card.dart';

class SearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> shops;
  const SearchScreen({super.key, required this.shops});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final List<Map<String, String>> _quickCategories = [
    {'icon': '🍔', 'name': 'Food'},
    {'icon': '🛒', 'name': 'Grocery'},
    {'icon': '💊', 'name': 'Pharmacy'},
    {'icon': '👗', 'name': 'Fashion'},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredShops = widget.shops.where((s) {
      final query = _searchQuery.toLowerCase();
      final name = s['name'].toString().toLowerCase();
      final cat = s['category'].toString().toLowerCase();
      
      // Also search within items if they exist
      bool itemMatch = false;
      if (s['items'] != null) {
        for (var item in (s['items'] as List)) {
          if (item['name'].toString().toLowerCase().contains(query)) {
            itemMatch = true;
            break;
          }
        }
      }

      return name.contains(query) || cat.contains(query) || itemMatch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('Search', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // 🔍 Search Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF272727)),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search for shops or products...',
                  hintStyle: const TextStyle(color: Color(0xFF555555)),
                  icon: const Icon(Icons.search, color: Color(0xFFFF4D4F)),
                  border: InputBorder.none,
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          // 📈 Results
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildRecentSearches()
                : filteredShops.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: filteredShops.length,
                        itemBuilder: (context, index) {
                          final shop = filteredShops[index];
                          return _buildSearchResultCard(shop);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              'Quick Categories',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _quickCategories.length,
              itemBuilder: (context, index) {
                final cat = _quickCategories[index];
                return CategoryCard(
                  name: cat['name']!,
                  icon: cat['icon']!,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryProductsScreen(categoryName: cat['name']!),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Text('Try searching for:', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ['Hammer', 'Jeans', 'Pharmacy', 'Food', 'Laptop', 'Milk'].map((tag) {
                return ActionChip(
                  backgroundColor: const Color(0xFF1A1A1A),
                  label: Text(tag, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF333333))),
                  onPressed: () {
                    _searchController.text = tag;
                    setState(() => _searchQuery = tag);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, color: Color(0xFF222222), size: 80),
          const SizedBox(height: 16),
          Text('No results for "$_searchQuery"', style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const Text('Try a different keyword', style: TextStyle(color: Color(0xFF444444), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> shop) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF272727)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color(shop['color'] as int? ?? 0xFFFF4D4F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(shop['icon'] ?? '🏪', style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(shop['category'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF333333), size: 14),
          ],
        ),
      ),
    );
  }
}
