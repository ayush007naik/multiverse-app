import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/branding_service.dart';
import '../widgets/premium_ui_widgets.dart';
import 'property_detail_screen.dart';

class RealEstateScreen extends StatefulWidget {
  const RealEstateScreen({super.key});

  @override
  State<RealEstateScreen> createState() => _RealEstateScreenState();
}

class _RealEstateScreenState extends State<RealEstateScreen> {
  final BrandingService _brandingService = BrandingService();
  String _propertyTypeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _brandingService.streamProperties(),
      builder: (context, snapshot) {
        final properties = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final filteredProperties = _propertyTypeFilter == 'All'
            ? properties
            : properties
                .where((property) => property['type'] == _propertyTypeFilter)
                .toList();

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideAnimation(
                delay: const Duration(milliseconds: 100),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    'Real Estate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              FadeSlideAnimation(
                delay: const Duration(milliseconds: 200),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Browse curated buy and rent listings around Mandi.',
                    style: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeSlideAnimation(
                delay: const Duration(milliseconds: 300),
                child: _buildFilters(),
              ),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
                      )
                    : filteredProperties.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(0, 16, 0, 120),
                            itemCount: filteredProperties.length,
                            itemBuilder: (context, index) {
                              final property = filteredProperties[index];
                              return FadeSlideAnimation(
                                delay: Duration(milliseconds: 400 + (index * 100)),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PropertyDetailScreen(property: property),
                                      ),
                                    );
                                  },
                                  child: GlassCard(
                                    padding: EdgeInsets.zero,
                                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                    borderRadius: 24,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: const BorderRadius.vertical(
                                                top: Radius.circular(24),
                                              ),
                                              child: Image.network(
                                                property['image'] as String? ?? 'https://images.unsplash.com/photo-1580587767526-cf3671a05014?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                                                height: 200,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    Container(
                                                      height: 200,
                                                      color: Colors.grey[900],
                                                      child: const Icon(Icons.home_outlined, color: Colors.grey, size: 50),
                                                    ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 16,
                                              right: 16,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: BackdropFilter(
                                                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withOpacity(0.4),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: Colors.white.withOpacity(0.1),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      property['type'] as String? ?? 'Sale',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      property['title'] as String? ?? 'Property',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                property['price'] as String? ?? 'Contact for price',
                                                style: const TextStyle(
                                                  color: Color(0xFFFF4D4F),
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.location_on_rounded,
                                                    color: Color(0xFFFF4D4F),
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    property['location'] as String? ?? 'Mandi, HP',
                                                    style: const TextStyle(
                                                      color: Color(0xFFAAAAAA),
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeSlideAnimation(
        delay: const Duration(milliseconds: 400),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(32),
              borderRadius: 32,
              child: Column(
                children: const [
                  Icon(Icons.construction_rounded, color: Color(0xFFFF4D4F), size: 64),
                  SizedBox(height: 24),
                  Text(
                    'Coming Soon',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Real Estate features are under development',
                    style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: ['All', 'Buy', 'Rent'].map((type) {
          final selected = _propertyTypeFilter == type;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _propertyTypeFilter = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFF4D4F)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFF4D4F)
                        : Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF4D4F).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFBBBBBB),
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
