import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/premium_ui_widgets.dart';
import 'sell_property_screen.dart';

class SellPropertyCategoryScreen extends StatefulWidget {
  const SellPropertyCategoryScreen({super.key});

  @override
  State<SellPropertyCategoryScreen> createState() =>
      _SellPropertyCategoryScreenState();
}

class _SellPropertyCategoryScreenState
    extends State<SellPropertyCategoryScreen> {
  static const _bg = Color(0xFF000000);
  static const _orange = Color(0xFFFF7A1A);
  static const _purple = Color(0xFF7D4CFF);

  String? _selectedCategory;

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'House',
      'icon': '🏠',
      'desc': 'Independent house, bungalow or row house.',
      'displayIcon': Icons.home_rounded,
    },
    {
      'name': 'Flat / Apartment',
      'icon': '🏢',
      'desc': 'Residential units in multi-story buildings.',
      'displayIcon': Icons.apartment_rounded,
    },
    {
      'name': 'Villa',
      'icon': '🏡',
      'desc': 'Luxury independent homes in gated communities.',
      'displayIcon': Icons.villa_rounded,
    },
    {
      'name': 'Plot / Land',
      'icon': '🌳',
      'desc': 'Residential, commercial or agricultural land.',
      'displayIcon': Icons.landscape_rounded,
    },
    {
      'name': 'Shop / Showroom',
      'icon': '🏪',
      'desc': 'Commercial spaces for retail or showrooms.',
      'displayIcon': Icons.storefront_rounded,
    },
    {
      'name': 'Commercial Building',
      'icon': '🏬',
      'desc': 'Full buildings for business or commercial use.',
      'displayIcon': Icons.business_rounded,
    },
    {
      'name': 'Office Space',
      'icon': '🏢',
      'desc': 'Dedicated spaces for offices or workstations.',
      'displayIcon': Icons.work_rounded,
    },
    {
      'name': 'Warehouse',
      'icon': '🏭',
      'desc': 'Storage facilities and industrial godowns.',
      'displayIcon': Icons.factory_rounded,
    },
    {
      'name': 'PG / Hostel',
      'icon': '🛏',
      'desc': 'Paying guest and shared accommodations.',
      'displayIcon': Icons.bed_rounded,
    },
    {
      'name': 'Rental Property',
      'icon': '🔑',
      'desc': 'Any property specifically for long-term lease.',
      'displayIcon': Icons.house_siding_rounded,
    },
  ];

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
        title: Text(
          'SELL PROPERTY',
          style: GoogleFonts.orbitron(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
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
          Positioned(
            bottom: 100,
            left: -50,
            child: _GlowCircle(
              color: _orange.withValues(alpha: 0.08),
              size: 200,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      return _CategoryCard(
                        category: cat,
                        isSelected: _selectedCategory == cat['name'],
                        onSelect: (val) =>
                            setState(() => _selectedCategory = val),
                      );
                    },
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_orange, _purple]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'STEP 1',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SELECT PROPERTY CATEGORY',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'What type of property are you selling?',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_orange, _purple]),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: NeonButton(
        text: 'CONTINUE',
        onPressed: _selectedCategory == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SellPropertyScreen(initialCategory: _selectedCategory),
                  ),
                );
              },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Map<String, dynamic> category;
  final bool isSelected;
  final Function(String) onSelect;

  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: 20,
        opacity: isSelected ? 0.15 : 0.05,
        borderColor: isSelected
            ? const Color(0xFFFF7A1A)
            : Colors.white.withValues(alpha: 0.08),
        child: InkWell(
          onTap: () => onSelect(category['name']),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF7A1A).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    category['displayIcon'],
                    color: isSelected
                        ? const Color(0xFFFF7A1A)
                        : Colors.white70,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category['name'].toUpperCase(),
                        style: GoogleFonts.orbitron(
                          color: isSelected
                              ? const Color(0xFFFF7A1A)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category['desc'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFFFF7A1A),
                    size: 24,
                  ),
              ],
            ),
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
