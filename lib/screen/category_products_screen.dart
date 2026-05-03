import 'package:flutter/material.dart';
import '../widgets/category_card.dart';
import '../services/unsplash_service.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryName;

  const CategoryProductsScreen({super.key, required this.categoryName});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final List<Map<String, String>> categories = [
    {'icon': '', 'name': 'Furniture'},
    {'icon': '', 'name': 'Hardware'},
    {'icon': '', 'name': 'Clothing'},
    {'icon': '', 'name': 'Grocery'},
    {'icon': '', 'name': 'Pharmacy'},
    {'icon': '', 'name': 'Electronics'},
    {'icon': '', 'name': 'Beauty'},
    {'icon': '', 'name': 'Stationery'},
    {'icon': '', 'name': 'Fruits'},
    {'icon': '', 'name': 'Vegetables'},
    {'icon': '', 'name': 'Dairy'},
    {'icon': '', 'name': 'Meat'},
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategoryImages();
  }

  Future<void> _fetchCategoryImages() async {
    final updated = await Future.wait(
      categories.map((cat) async {
        final url = await UnsplashService.getImageUrl(cat['name']!);
        return {...cat, 'icon': url ?? ''};
      }),
    );

    if (mounted) {
      setState(() {
        categories
          ..clear()
          ..addAll(updated.map((e) => e.cast<String, String>()));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Text(
          widget.categoryName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : GridView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemBuilder: (ctx, i) {
          final cat = categories[i];
          return CategoryCard(
            name: cat['name']!,
            icon: cat['icon']!,
            margin: EdgeInsets.zero,
            size: (MediaQuery.of(context).size.width - 72) / 3,
            onTap: () {
              // Navigate to product details or similar
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}
