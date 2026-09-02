import 'package:flutter/material.dart';

import '../models/category_model.dart';
import 'category_item.dart';

/// Premium Swiggy/Zomato inspired Categories Section
/// Features:
/// - Horizontal scrolling with smooth physics
/// - Responsive sizing for all devices
/// - Proper spacing and padding
/// - Smooth animations
/// - Production-ready implementation

class CategoriesSection extends StatelessWidget {
  final List<Category> categories;
  final String selectedCategory;
  final ValueChanged<Category> onCategoryTap;

  const CategoriesSection({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 114,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        padding: const EdgeInsets.only(right: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          return CategoryItem(
            category: category,
            isSelected: selectedCategory == category.name,
            onTap: () => onCategoryTap(category),
          );
        },
      ),
    );
  }
}