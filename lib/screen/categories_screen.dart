import 'package:flutter/material.dart';
import 'category_products_screen.dart';
import '../widgets/category_card.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    //  Categories (using Unsplash images instead of emojis)
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

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text('All Categories', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GridView.builder(
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
            size: (MediaQuery.of(context).size.width - 72) / 3, // Calculate size based on grid
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
    );
  }
}
