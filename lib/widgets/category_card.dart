// lib/widgets/category_card.dart

import 'package:flutter/material.dart';
import '../services/unsplash_service.dart';

class CategoryCard extends StatefulWidget {
  final String name;
  final String icon; // imageUrl ya empty string
  final bool isSelected;
  final VoidCallback onTap;
  final EdgeInsets margin;
  final double? size;

  const CategoryCard({
    super.key,
    required this.name,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
    this.margin = const EdgeInsets.only(right: 12),
    this.size,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  String? _imageUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    // Agar icon already URL hai toh use karo
    if (widget.icon.startsWith('http')) {
      setState(() {
        _imageUrl = widget.icon;
        _loading = false;
      });
      return;
    }

    // "All" category ke liye image mat fetch karo
    if (widget.name == 'All') {
      setState(() => _loading = false);
      return;
    }

    // Unsplash se fetch karo
    final url = await UnsplashService.getCategoryImage(widget.name);
    if (mounted) {
      setState(() {
        _imageUrl = url;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardSize = widget.size ?? 72.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: widget.margin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image Circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: cardSize,
              height: cardSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isSelected
                      ? const Color(0xFFFF4D4F)
                      : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: widget.isSelected
                    ? [
                  BoxShadow(
                    color: const Color(0xFFFF4D4F).withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
                    : [],
              ),
              child: ClipOval(
                child: widget.name == 'All'
                    ? _buildAllIcon(cardSize)
                    : _loading
                    ? _buildShimmer(cardSize)
                    : _imageUrl != null
                    ? Image.network(
                  _imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _buildFallback(),
                )
                    : _buildFallback(),
              ),
            ),

            const SizedBox(height: 6),

            // Category Name
            Text(
              widget.name,
              style: TextStyle(
                color: widget.isSelected
                    ? const Color(0xFFFF4D4F)
                    : Colors.white,
                fontSize: 11,
                fontWeight: widget.isSelected
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // "All" ke liye grid icon
  Widget _buildAllIcon(double size) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Icon(
        Icons.grid_view_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  // Loading shimmer
  Widget _buildShimmer(double size) {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFF4D4F),
          ),
        ),
      ),
    );
  }

  // Fallback icon
  Widget _buildFallback() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Icon(
        Icons.storefront_outlined,
        color: Colors.grey,
        size: 28,
      ),
    );
  }
}
