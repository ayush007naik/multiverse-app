import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../services/unsplash_service.dart';

class CategoryImage extends StatelessWidget {
  final String categoryName;
  final String emoji;

  const CategoryImage({
    super.key,
    required this.categoryName,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: UnsplashService.getCategoryImage(categoryName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmer();
        }

        final imageUrl = snapshot.data ?? 'https://source.unsplash.com/400x400/?$categoryName';

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Network Image - Primary Content
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallback(),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildShimmer();
                },
              ),
              
              // Subtle gradient overlay for better visual hierarchy
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E1E),
      highlightColor: const Color(0xFF272727),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}
