import 'package:flutter/material.dart';
import '../models/category_model.dart';

/// Premium Swiggy/Zomato inspired Category Widget
/// Features:
/// - Circular dark neumorphic container (68px)
/// - Orange glow border on selected category
/// - Smooth tap animation
/// - BoxFit.contain for perfect image fitting
/// - Fallback to icon if image missing
/// - White text with proper spacing
/// - Shadow and glow effects

class CategoryWidget extends StatefulWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;
  final double? size;

  const CategoryWidget({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.size = 68.0,
  });

  @override
  State<CategoryWidget> createState() => _CategoryWidgetState();
}

class _CategoryWidgetState extends State<CategoryWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _animationController.forward();
      },
      onTapUp: (_) {
        _animationController.reverse();
      },
      onTapCancel: () {
        _animationController.reverse();
      },
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size!,
              height: widget.size!,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E1E1E), // Dark neumorphic background
                border: Border.all(
                  color: widget.isSelected
                      ? const Color(0xFFFF5722) // Orange accent
                      : Colors.transparent,
                  width: 2.0,
                ),
                boxShadow: [
                  // Inner shadow for neumorphic effect
                  const BoxShadow(
                    color: Color(0x20FFFFFF),
                    offset: Offset(-2, -2),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                  const BoxShadow(
                    color: Color(0x20000000),
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                  // Outer glow effect
                  if (widget.isSelected)
                    BoxShadow(
                      color: const Color(0xFFFF5722).withValues(alpha: 0.6),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 0),
                    ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Category image
                  ClipOval(
                    child: Image.asset(
                      widget.category.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to icon if image fails to load
                        return Icon(
                          _getFallbackIcon(widget.category.name),
                          color: Colors.white70,
                          size: 32,
                        );
                      },
                    ),
                  ),
                  // Category title
                  Positioned(
                    bottom: -12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        widget.category.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getFallbackIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'grocery':
        return Icons.local_grocery_store_rounded;
      case 'pharmacy':
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'electronics':
      case 'devices':
        return Icons.devices_rounded;
      case 'beauty':
      case 'spa':
        return Icons.spa_rounded;
      case 'fashion':
      case 'clothing':
        return Icons.checkroom_rounded;
      case 'furniture':
      case 'chair':
        return Icons.chair_rounded;
      case 'baby & kids':
      case 'baby':
      case 'kids':
        return Icons.child_care_rounded;
      case 'books':
      case 'book':
        return Icons.menu_book_rounded;
      case 'hardware':
      case 'tools':
        return Icons.hardware_rounded;
      case 'materials':
      case 'inventory':
        return Icons.inventory_2_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
