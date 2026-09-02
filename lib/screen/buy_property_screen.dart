import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/property_model.dart';
import '../services/property_service.dart';
import '../services/auto_location_service.dart';
import '../widgets/premium_property_card.dart';

class BuyPropertyScreen extends StatefulWidget {
  final String initialCategory;
  const BuyPropertyScreen({super.key, this.initialCategory = 'See All'});

  @override
  State<BuyPropertyScreen> createState() => _BuyPropertyScreenState();
}

class _BuyPropertyScreenState extends State<BuyPropertyScreen> {
  static const _bg = Color(0xFF000000);
  static const _orange = Color(0xFFFF7A1A);
  static const _purple = Color(0xFF7D4CFF);

  final PropertyService _service = PropertyService();

  // Filter States
  late String _selectedCategory;
  String _selectedPurpose = 'Any';
  String _selectedBudget = 'Any';
  String _selectedBhk = 'Any';
  String _selectedArea = 'Any';
  String _selectedFurnishing = 'Any';
  List<String> _selectedAmenities = [];
  String _selectedPosted = 'Any';

  // Sort State
  String _selectedSort = 'Recommended';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          _selectedCategory.toUpperCase(),
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: _GlowCircle(
              color: _purple.withValues(alpha: 0.1),
              size: 250,
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 10),
              _buildFilterSortBar(),
              const SizedBox(height: 15),
              Expanded(child: _buildPropertyList()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSortBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _PremiumActionChip(
              label: 'FILTER',
              icon: Icons.tune_rounded,
              onTap: _showFilterSheet,
              active: _hasActiveFilters(),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _PremiumActionChip(
              label: 'SORT',
              icon: Icons.sort_rounded,
              onTap: _showSortSheet,
              active: _selectedSort != 'Recommended',
            ),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedPurpose != 'Any' ||
        _selectedBudget != 'Any' ||
        _selectedBhk != 'Any' ||
        _selectedArea != 'Any' ||
        _selectedFurnishing != 'Any' ||
        _selectedAmenities.isNotEmpty ||
        _selectedPosted != 'Any';
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PremiumSheet(
        title: 'SORT BY',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            'Recommended',
            'Newest First',
            'Price Low → High',
            'Price High → Low',
            'Area Largest First',
            'Area Smallest First',
            'Most Viewed',
            'Most Contacted',
          ].map((option) => _buildSortOption(option)).toList(),
        ),
      ),
    );
  }

  Widget _buildSortOption(String option) {
    final isSelected = _selectedSort == option;
    return ListTile(
      onTap: () {
        setState(() => _selectedSort = option);
        Navigator.pop(context);
      },
      contentPadding: EdgeInsets.zero,
      title: Text(
        option.toUpperCase(),
        style: GoogleFonts.orbitron(
          color: isSelected ? _orange : Colors.white70,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: _orange, size: 20)
          : const Icon(Icons.circle_outlined, color: Colors.white10, size: 20),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateState(VoidCallback fn) {
              setSheetState(fn);
              setState(fn); // Real-time update main list
            }

            return _PremiumSheet(
              title: 'FILTERS',
              isScrollable: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetSection(
                    'Purpose',
                    ['Buy', 'Rent', 'Lease'],
                    _selectedPurpose,
                    (v) => updateState(() => _selectedPurpose = v),
                  ),

                  _sheetSection(
                    'Budget',
                    [
                      'Under ₹10L',
                      '₹10L - ₹25L',
                      '₹25L - ₹50L',
                      '₹50L - ₹1CR',
                      '₹1CR+',
                    ],
                    _selectedBudget,
                    (v) => updateState(() => _selectedBudget = v),
                  ),

                  _sheetSection(
                    'BHK',
                    ['1 BHK', '2 BHK', '3 BHK', '4+ BHK'],
                    _selectedBhk,
                    (v) => updateState(() => _selectedBhk = v),
                  ),

                  _sheetSection(
                    'Area',
                    ['500 sqft+', '1000 sqft+', '2000 sqft+'],
                    _selectedArea,
                    (v) => updateState(() => _selectedArea = v),
                  ),

                  _sheetSection(
                    'Furnishing',
                    ['Furnished', 'Semi Furnished', 'Unfurnished'],
                    _selectedFurnishing,
                    (v) => updateState(() => _selectedFurnishing = v),
                  ),

                  _sheetLabel('Amenities'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children:
                        [
                          'Parking',
                          'Lift',
                          'Security',
                          'Power Backup',
                          'Garden',
                          'Swimming Pool',
                        ].map((a) {
                          final isSelected = _selectedAmenities.contains(a);
                          return _FilterChip(
                            label: a,
                            isSelected: isSelected,
                            onTap: () => updateState(() {
                              isSelected
                                  ? _selectedAmenities.remove(a)
                                  : _selectedAmenities.add(a);
                            }),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 20),

                  _sheetSection(
                    'Posted',
                    ['Today', 'Last 7 Days', 'Last 30 Days'],
                    _selectedPosted,
                    (v) => updateState(() => _selectedPosted = v),
                  ),

                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: _PremiumButton(
                          label: 'RESET',
                          isOutlined: true,
                          onPressed: () {
                            setState(() {
                              _selectedPurpose = 'Any';
                              _selectedBudget = 'Any';
                              _selectedBhk = 'Any';
                              _selectedArea = 'Any';
                              _selectedFurnishing = 'Any';
                              _selectedAmenities = [];
                              _selectedPosted = 'Any';
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _PremiumButton(
                          label: 'DONE',
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetSection(
    String label,
    List<String> options,
    String current,
    Function(String) onSelect,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetLabel(label),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options
              .map(
                (o) => _FilterChip(
                  label: o,
                  isSelected: current == o,
                  onTap: () => onSelect(o),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _sheetLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.orbitron(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildPropertyList() {
    return StreamBuilder<List<Property>>(
      stream: _service.streamActiveProperties(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _orange));
        }

        final all = snapshot.data ?? [];

        List<Property> filtered = all.where((p) {
          // 1. Category Match (e.g., House, Villa)
          if (_selectedCategory != 'See All') {
            final cat = _selectedCategory.toLowerCase();
            final type = p.type.toLowerCase();
            final category = p.category.toLowerCase();
            bool matches = false;
            if (cat == 'house') {
              matches = type.contains('house') || type.contains('home');
            } else if (cat == 'flat / apartment')
              matches = type.contains('flat') || type.contains('apartment');
            else if (cat == 'plot / land')
              matches = type.contains('plot') || type.contains('land');
            else if (cat == 'pg / hostel')
              matches = type.contains('pg') || type.contains('hostel');
            else if (cat == 'rental property')
              matches = category.contains('rent');
            else
              matches = type.contains(cat) || category.contains(cat);
            if (!matches) return false;
          }

          // 2. Purpose Match (Buy, Rent, Lease)
          if (_selectedPurpose != 'Any') {
            final purpose = _selectedPurpose.toLowerCase();
            final pCategory = p.category.toLowerCase();
            if (!pCategory.contains(purpose)) return false;
          }

          // 3. BHK Filter
          if (_selectedBhk != 'Any') {
            final bedrooms =
                int.tryParse(p.beds.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            if (_selectedBhk == '1 BHK' && bedrooms != 1) return false;
            if (_selectedBhk == '2 BHK' && bedrooms != 2) return false;
            if (_selectedBhk == '3 BHK' && bedrooms != 3) return false;
            if (_selectedBhk == '4+ BHK' && bedrooms < 4) return false;
          }

          // 4. Budget Filter
          final price = _priceValue(p.price);
          if (_selectedBudget == 'Under ₹10L') {
            if (price >= 1000000) return false;
          } else if (_selectedBudget == '₹10L - ₹25L') {
            if (price < 1000000 || price > 2500000) return false;
          } else if (_selectedBudget == '₹25L - ₹50L') {
            if (price < 2500000 || price > 5000000) return false;
          } else if (_selectedBudget == '₹50L - ₹1CR') {
            if (price < 5000000 || price > 10000000) return false;
          } else if (_selectedBudget == '₹1CR+') {
            if (price < 10000000) return false;
          }

          // 5. Area Filter
          if (_selectedArea != 'Any') {
            final areaVal = _areaValue(p.area);
            if (_selectedArea == '500 sqft+' && areaVal < 500) return false;
            if (_selectedArea == '1000 sqft+' && areaVal < 1000) return false;
            if (_selectedArea == '2000 sqft+' && areaVal < 2000) return false;
          }

          // 6. Furnishing Filter
          if (_selectedFurnishing != 'Any') {
            final desc = p.description.toLowerCase();
            if (!desc.contains(_selectedFurnishing.toLowerCase())) return false;
          }

          // 7. Amenities Filter (Multi-select: Match all selected)
          if (_selectedAmenities.isNotEmpty) {
            final pAmenities = p.amenities.map((a) => a.toLowerCase()).toList();
            for (final amenity in _selectedAmenities) {
              if (!pAmenities.contains(amenity.toLowerCase())) return false;
            }
          }

          // 8. Posted Filter
          if (_selectedPosted != 'Any') {
            final now = DateTime.now();
            final difference = now.difference(p.createdAt).inDays;
            if (_selectedPosted == 'Today' && difference > 0) return false;
            if (_selectedPosted == 'Last 7 Days' && difference > 7) {
              return false;
            }
            if (_selectedPosted == 'Last 30 Days' && difference > 30) {
              return false;
            }
          }

          return true;
        }).toList();

        // 9. Sorting Logic
        if (_selectedSort != 'Recommended') {
          filtered.sort((a, b) {
            switch (_selectedSort) {
              case 'Price Low → High':
                return _priceValue(a.price).compareTo(_priceValue(b.price));
              case 'Price High → Low':
                return _priceValue(b.price).compareTo(_priceValue(a.price));
              case 'Newest First':
                return b.createdAt.compareTo(a.createdAt);
              case 'Area Largest First':
                return _areaValue(b.area).compareTo(_areaValue(a.area));
              case 'Area Smallest First':
                return _areaValue(a.area).compareTo(_areaValue(b.area));
              case 'Most Viewed':
                return b.trustScore.compareTo(
                  a.trustScore,
                ); // Placeholder for views
              default:
                return b.createdAt.compareTo(a.createdAt);
            }
          });
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 20),
            itemBuilder: (context, index) =>
                PremiumPropertyCard(property: filtered[index]),
          );
        }

        // 10. Recommended Sorting (Priority + Distance)
        final locationService = context.read<AutoLocationService>();

        double getDistance(Property p) {
          if (p.mapLocation.isEmpty) return 999999;
          try {
            final parts = p.mapLocation.split(',');
            if (parts.length == 2) {
              final lat = double.tryParse(parts[0].trim()) ?? 0;
              final lng = double.tryParse(parts[1].trim()) ?? 0;
              if (lat != 0 && lng != 0) {
                return locationService.distanceTo(lat, lng) ?? 999999;
              }
            }
          } catch (_) {}
          return 999999;
        }

        final verified = filtered.where((p) => p.isVerified).toList();
        final featured = filtered
            .where((p) => !p.isVerified && p.isFeatured)
            .toList();
        final others = filtered
            .where((p) => !p.isVerified && !p.isFeatured)
            .toList();

        int compareByDistance(Property a, Property b) {
          final d1 = getDistance(a);
          final d2 = getDistance(b);
          if (d1 != d2) return d1.compareTo(d2);
          return a.location.toLowerCase().compareTo(b.location.toLowerCase());
        }

        verified.sort(compareByDistance);
        featured.sort(compareByDistance);
        others.sort(compareByDistance);

        final sortedList = [...verified, ...featured, ...others];

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
          itemCount: sortedList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 20),
          itemBuilder: (context, index) =>
              PremiumPropertyCard(property: sortedList[index]),
        );
      },
    );
  }

  double _priceValue(String p) {
    final n = double.tryParse(p.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final lower = p.toLowerCase();
    if (lower.contains('cr')) return n * 10000000;
    if (lower.contains('l')) return n * 100000;
    if (lower.contains('k')) return n * 1000;
    return n;
  }

  double _areaValue(String a) =>
      double.tryParse(a.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
}

class _PremiumActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _PremiumActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFFF7A1A).withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: active ? const Color(0xFFFF7A1A) : Colors.white10,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFFFF7A1A) : Colors.white54,
              size: 16,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.orbitron(
                color: active ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isScrollable;
  const _PremiumSheet({
    required this.title,
    required this.child,
    this.isScrollable = false,
  });
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white38,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (isScrollable)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  child: SingleChildScrollView(child: child),
                )
              else
                child,
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF7A1A)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7A1A) : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PremiumButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isOutlined;
  const _PremiumButton({
    required this.label,
    required this.onPressed,
    this.isOutlined = false,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isOutlined
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFFF7A1A), Color(0xFF7D4CFF)],
                ),
          color: isOutlined ? Colors.transparent : null,
          borderRadius: BorderRadius.circular(12),
          border: isOutlined ? Border.all(color: Colors.white24) : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowCircle({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: size / 2, spreadRadius: size / 4),
        ],
      ),
    );
  }
}
