import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/property_model.dart';
import '../services/property_service.dart';
import '../widgets/premium_ui_widgets.dart';
import 'property_detail_screen.dart';

class RealEstateScreen extends StatefulWidget {
  final bool isTab;
  const RealEstateScreen({super.key, this.isTab = false});

  @override
  State<RealEstateScreen> createState() => _RealEstateScreenState();
}

class _RealEstateScreenState extends State<RealEstateScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PropertyService _propertyService = PropertyService();
  
  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<String> _categories = ['All'];
  List<Property> _allProperties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _listenToProperties();
  }

  void _loadCategories() async {
    final categories = await _propertyService.getCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
      });
    }
  }

  void _listenToProperties() {
    _propertyService.streamActiveProperties().listen((properties) {
      if (mounted) {
        setState(() {
          _allProperties = properties;
          _isLoading = false;
        });
        debugPrint('🏡 Real Estate: ${properties.length} properties loaded');
      }
    }).onError((error) {
      debugPrint('❌ Error streaming properties: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Property> get _filteredProperties {
    final lowerQuery = _searchQuery.trim().toLowerCase();
    
    return _allProperties.where((property) {
      // Category filter
      final categoryMatch = _selectedCategory == 'All' ||
          property.type.toLowerCase() == _selectedCategory.toLowerCase() ||
          property.category.toLowerCase() == _selectedCategory.toLowerCase();

      // Search query
      final queryMatch = lowerQuery.isEmpty ||
          property.title.toLowerCase().contains(lowerQuery) ||
          property.location.toLowerCase().contains(lowerQuery) ||
          property.type.toLowerCase().contains(lowerQuery) ||
          property.category.toLowerCase().contains(lowerQuery);

      return categoryMatch && queryMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        _buildHeader(),
        _buildSearchBar(),
        _buildCategoryStrip(),
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _filteredProperties.isEmpty
                  ? _buildEmptyState()
                  : _buildPropertyList(),
        ),
      ],
    );

    if (widget.isTab) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF09090C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A0D),
              Color(0xFF120F17),
              Color(0xFF17111E),
              Color(0xFF09090C),
            ],
          ),
        ),
        child: SafeArea(
          child: content,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFFFF6A3D),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading properties...',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeSlideAnimation(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6A3D).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF6A3D).withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 60,
                color: Color(0xFFFF6A3D),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No matching properties found',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try adjusting your search terms or\nselecting a different category.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: NeonButton(
                text: 'RESET FILTERS',
                onPressed: () {
                  setState(() {
                    _selectedCategory = 'All';
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyList() {
    final properties = _filteredProperties;
    
    return ListView.builder(
      key: ValueKey('property_list_${_selectedCategory}_$_searchQuery'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final property = properties[index];
        return FadeSlideAnimation(
          key: ValueKey(property.id),
          delay: Duration(milliseconds: 50 * index),
          child: _buildPropertyCard(property),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Real Estate',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Premium properties for every lifestyle',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: GlassCard(
        margin: EdgeInsets.zero,
        borderRadius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            icon: const Icon(Icons.search_rounded, color: Color(0xFFFF6A3D)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, 
                      color: Colors.white54, 
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            hintText: 'Search title, location, type...',
            hintStyle: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryStrip() {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFFFF6A3D).withValues(alpha: 0.15) 
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFFFF6A3D) 
                      : Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: const Color(0xFFFF6A3D).withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ] : [],
              ),
              child: Text(
                category,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PropertyDetailScreen(property: property),
          ),
        );
      },
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 18),
        padding: EdgeInsets.zero,
        borderRadius: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Image with Network Image Support
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Stack(
                children: [
                  _buildPropertyImage(property),
                  
                  // Category Badge
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6A3D), Color(0xFFB54DFF)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6A3D).withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        property.type,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Property Details
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        property.price,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFF6A3D),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFFF6A3D),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          property.location,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Property Meta Pills (NO TOKEN)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildMetaPill(
                        Icons.square_foot_rounded,
                        property.area,
                      ),
                      if (property.beds != '0')
                        _buildMetaPill(
                          Icons.bed_rounded,
                          '${property.beds} ${int.parse(property.beds) > 1 ? 'Beds' : 'Bed'}',
                        ),
                      if (property.baths != '0')
                        _buildMetaPill(
                          Icons.bathtub_rounded,
                          '${property.baths} ${int.parse(property.baths) > 1 ? 'Baths' : 'Bath'}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyImage(Property property) {
    // Check if we have any images
    if (property.images.isEmpty) {
      return _buildPlaceholderImage();
    }

    final imageUrl = property.images.first;
    
    // Check if it's a network URL or local asset
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      // Network Image with Cache
      return CachedNetworkImage(
        imageUrl: imageUrl,
        height: 240,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 240,
          color: const Color(0xFF1A1A1A),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFF6A3D),
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholderImage(),
      );
    } else {
      // Local Asset Image with Error Handling
      return Image.asset(
        imageUrl,
        height: 240,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Failed to load asset: $imageUrl');
          return _buildPlaceholderImage();
        },
      );
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A1A),
            Color(0xFF2A2A2A),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.apartment_rounded,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 8),
          Text(
            'Image Unavailable',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: const Color(0xFFFF6A3D),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
