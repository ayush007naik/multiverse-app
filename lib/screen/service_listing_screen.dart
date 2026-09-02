import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/auto_location_service.dart';
import '../widgets/premium_ui_widgets.dart';
import '../services/service_provider_service.dart';
import '../services/fee_config_service.dart';
import 'service_detail_screen_v2.dart';
import '../utils/price_calculator.dart';

class ServiceListingScreen extends StatefulWidget {
  final String category;
  const ServiceListingScreen({super.key, required this.category});

  @override
  State<ServiceListingScreen> createState() => _ServiceListingScreenState();
}

class _ServiceListingScreenState extends State<ServiceListingScreen> {
  final ServiceProviderService _service = ServiceProviderService();
  final TextEditingController _searchController = TextEditingController();
  String _selectedSubCategory = 'General';

  @override
  void initState() {
    super.initState();
    _selectedSubCategory = _getSubCategories()[0]['name'];
    _feeSub = FeeConfigService.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  StreamSubscription<Map<String, double>>? _feeSub;

  @override
  void dispose() {
    _feeSub?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _getSubCategories() {
    const Color orange = Color(0xFFFF7A1A);
    const Color purple = Color(0xFF7D4CFF);

    switch (widget.category) {
      case 'Doctors':
        return [
          {
            'name': 'General',
            'icon': Icons.medical_services_outlined,
            'color': orange,
          },
          {
            'name': 'Orthopedic',
            'icon': Icons.accessibility_new_rounded,
            'color': purple,
          },
          {
            'name': 'Pediatrician',
            'icon': Icons.child_care_rounded,
            'color': orange,
          },
          {
            'name': 'Gynecologist',
            'icon': Icons.pregnant_woman_rounded,
            'color': purple,
          },
          {
            'name': 'Dermatologist',
            'icon': Icons.face_retouching_natural_rounded,
            'color': orange,
          },
          {'name': 'ENT', 'icon': Icons.hearing_rounded, 'color': purple},
          {
            'name': 'Eye Specialist',
            'icon': Icons.visibility_rounded,
            'color': orange,
          },
          {
            'name': 'Cardiologist',
            'icon': Icons.favorite_outline_rounded,
            'color': purple,
          },
          {
            'name': 'Neurologist',
            'icon': Icons.psychology_outlined,
            'color': orange,
          },
          {
            'name': 'Physio',
            'icon': Icons.fitness_center_rounded,
            'color': purple,
          },
        ];
      case 'Dentists':
        return [
          {
            'name': 'General',
            'icon': Icons.medical_services_outlined,
            'color': orange,
          },
          {
            'name': 'Teeth Cleaning',
            'icon': Icons.clean_hands_rounded,
            'color': purple,
          },
          {
            'name': 'Root Canal',
            'icon': Icons.biotech_rounded,
            'color': orange,
          },
          {
            'name': 'Teeth Whitening',
            'icon': Icons.brightness_7_rounded,
            'color': purple,
          },
          {'name': 'Braces', 'icon': Icons.grid_view_rounded, 'color': orange},
          {
            'name': 'Dental Implant',
            'icon': Icons.settings_input_component_rounded,
            'color': purple,
          },
          {
            'name': 'Pediatric',
            'icon': Icons.child_care_rounded,
            'color': orange,
          },
          {
            'name': 'Tooth Extraction',
            'icon': Icons.remove_circle_outline_rounded,
            'color': purple,
          },
        ];
      case 'Salons':
        return [
          {
            'name': 'Haircut',
            'icon': Icons.content_cut_rounded,
            'color': orange,
          },
          {
            'name': 'Beard Styling',
            'icon': Icons.face_retouching_natural_rounded,
            'color': purple,
          },
          {'name': 'Hair Spa', 'icon': Icons.spa_rounded, 'color': orange},
          {
            'name': 'Hair Coloring',
            'icon': Icons.palette_rounded,
            'color': purple,
          },
          {
            'name': 'Makeup',
            'icon': Icons.face_retouching_natural_rounded,
            'color': orange,
          },
          {
            'name': 'Bridal Makeup',
            'icon': Icons.auto_awesome_rounded,
            'color': purple,
          },
          {
            'name': 'Nail Services',
            'icon': Icons.brush_rounded,
            'color': orange,
          },
          {
            'name': 'Facial & Care',
            'icon': Icons.face_rounded,
            'color': purple,
          },
        ];
      case 'Diagnostic Labs':
        return [
          {
            'name': 'Blood Test',
            'icon': Icons.bloodtype_outlined,
            'color': orange,
          },
          {
            'name': 'Diabetes Test',
            'icon': Icons.monitor_weight_outlined,
            'color': purple,
          },
          {
            'name': 'Thyroid Test',
            'icon': Icons.biotech_rounded,
            'color': orange,
          },
          {
            'name': 'Full Body',
            'icon': Icons.monitor_weight_outlined,
            'color': purple,
          },
          {
            'name': 'X-Ray',
            'icon': Icons.document_scanner_rounded,
            'color': orange,
          },
          {
            'name': 'MRI',
            'icon': Icons.settings_overscan_rounded,
            'color': purple,
          },
          {'name': 'CT Scan', 'icon': Icons.scanner_rounded, 'color': orange},
          {
            'name': 'Urine Test',
            'icon': Icons.opacity_rounded,
            'color': purple,
          },
        ];
      case 'Car Services':
        return [
          {
            'name': 'General Service',
            'icon': Icons.build_circle_outlined,
            'color': orange,
          },
          {
            'name': 'Oil Change',
            'icon': Icons.water_drop_outlined,
            'color': purple,
          },
          {
            'name': 'Car Wash',
            'icon': Icons.local_car_wash_rounded,
            'color': orange,
          },
          {
            'name': 'Detailing',
            'icon': Icons.auto_awesome_rounded,
            'color': purple,
          },
          {
            'name': 'AC Service',
            'icon': Icons.ac_unit_rounded,
            'color': orange,
          },
          {
            'name': 'Alignment',
            'icon': Icons.settings_input_component_rounded,
            'color': purple,
          },
          {
            'name': 'Battery',
            'icon': Icons.battery_charging_full_rounded,
            'color': orange,
          },
          {
            'name': 'Dent & Paint',
            'icon': Icons.format_paint_rounded,
            'color': purple,
          },
        ];
      default:
        return [];
    }
  }

  Map<String, dynamic> _mapPartnerToProvider(
    Map<String, dynamic> partner,
    Position? userPos,
  ) {
    // 1. Extract base data with fallbacks for flattened or nested structures
    final basicInfo = partner['basic_info'] ?? {};
    final profDetails = partner['professional_details'] ?? {};
    final businessDetails = partner['business_details'] ?? {};
    final pricing = partner['pricing'] ?? {};
    final services = pricing['services'] as List? ?? [];

    // 2. Resolve Name
    final String name =
        (partner['full_name'] ??
                basicInfo['full_name'] ??
                partner['name'] ??
                'Provider')
            .toString()
            .toUpperCase();

    // 3. Resolve Experience (Signup field is 'experience' in professional_details)
    final dynamic rawExp =
        profDetails['experience'] ??
        partner['experience'] ??
        partner['exp'] ??
        0;
    int expInt = 0;
    if (rawExp is num) {
      expInt = rawExp.toInt();
    } else if (rawExp is String)
      expInt = int.tryParse(rawExp) ?? 0;
    final String exp = '$expInt YRS EXP';

    // 4. Resolve Rating (Real-time from dashboard)
    final double rating = (partner['rating'] ?? 0.0).toDouble();
    final int rev = (partner['reviews_count'] ?? partner['totalReviews'] ?? 0)
        .toInt();

    // 5. Resolve Fee (Booking Amount)
    final int fee =
        (partner['bookingAmount'] ??
                (services.isNotEmpty ? (services[0]['price'] ?? 0) : 0))
            .toInt();

    // 6. Resolve Professional Info
    final String info =
        (profDetails['qualification'] ??
                partner['qualification'] ??
                'Professional')
            .toString();
    // Resolve Specialties (Prefer multi-select from signup/dashboard)
    final List<String> subs = List<String>.from(
      profDetails['selectedSubCategories'] ??
          partner['selectedSubCategories'] ??
          [
            (profDetails['specialization'] ??
                    profDetails['salon_type'] ??
                    partner['specialization'] ??
                    'General')
                .toString(),
          ],
    );
    final String sub = subs.join(", ");

    // 7. REAL-TIME DISTANCE CALCULATION
    String dist = '-- KM';
    if (userPos != null) {
      double? lat;
      double? lng;

      // Try resolving coordinates from all possible signup/firestore paths
      // Check business_details.location (Standard signup path)
      if (businessDetails['location'] != null) {
        lat = _asDouble(
          businessDetails['location']['lat'] ??
              businessDetails['location']['latitude'],
        );
        lng = _asDouble(
          businessDetails['location']['lng'] ??
              businessDetails['location']['longitude'],
        );
      }
      // Check top-level location
      if (lat == null && partner['location'] != null) {
        lat = _asDouble(
          partner['location']['lat'] ?? partner['location']['latitude'],
        );
        lng = _asDouble(
          partner['location']['lng'] ?? partner['location']['longitude'],
        );
      }
      // Check coordinates field directly
      if (lat == null) {
        lat = _asDouble(partner['lat'] ?? partner['latitude']);
        lng = _asDouble(partner['lng'] ?? partner['longitude']);
      }

      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        final double distanceInMeters = Geolocator.distanceBetween(
          userPos.latitude,
          userPos.longitude,
          lat,
          lng,
        );
        dist = '${(distanceInMeters / 1000).toStringAsFixed(1)} KM';
      }
    }

    // 8. Resolve Image
    final String img =
        (basicInfo['profile_image'] ??
                partner['profile_image'] ??
                partner['images']?['profile'] ??
                '')
            .toString();
    String finalImg = img;
    if (finalImg.isEmpty) {
      switch (widget.category) {
        case 'Doctors':
          finalImg = 'assets/doctor.png';
          break;
        case 'Dentists':
          finalImg = 'assets/dentist.png';
          break;
        case 'Salons':
          finalImg = 'assets/salon.png';
          break;
        case 'Diagnostic Labs':
          finalImg = 'assets/microscope.png';
          break;
        case 'Car Services':
          finalImg = 'assets/car_service.png';
          break;
        default:
          finalImg = 'assets/doctor.png';
      }
    }

    return {
      'id': partner['id'],
      'name': name,
      'info': info,
      'sub': sub,
      'exp': exp,
      'rating': rating,
      'rev': rev,
      'fee': fee,
      'dist': dist,
      'img': finalImg,
      'cat': widget.category,
      'subs': subs,
      'full_partner_data': partner,
    };
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const Color orange = Color(0xFFFF7A1A);
    const Color purple = Color(0xFF7D4CFF);
    const Color bg = Color(0xFF08090D);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: purple.withAlpha(25),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: orange.withAlpha(20),
                ),
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: bg.withAlpha(204),
                floating: true,
                pinned: true,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  widget.category.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildSearchBar(orange),
                      const SizedBox(height: 20),
                      Text(
                        'CATEGORIES',
                        style: GoogleFonts.rajdhani(
                          color: orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSubCategoriesGrid(),
                      const SizedBox(height: 24),
                      Text(
                        'NEARBY PROVIDERS',
                        style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _service.getPartnersByCategory(widget.category),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF7A1A),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          'Error loading providers',
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  final autoLocation = Provider.of<AutoLocationService>(
                    context,
                  );
                  final userPos = autoLocation.currentPosition;
                  final allPartners = snapshot.data ?? [];
                  final filteredProviders = allPartners
                      .map((p) => _mapPartnerToProvider(p, userPos))
                      .where(
                        (p) =>
                            (_selectedSubCategory == 'General' ||
                                p['subs'].contains(_selectedSubCategory)) &&
                            (p['name'].toLowerCase().contains(
                              _searchController.text.toLowerCase(),
                            )),
                      )
                      .toList();

                  if (filteredProviders.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person_search_rounded,
                              color: Colors.white24,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'NO PROVIDERS FOUND',
                              style: GoogleFonts.rajdhani(
                                color: Colors.white54,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => FadeSlideAnimation(
                          child: _buildProviderCard(
                            filteredProviders[index],
                            orange,
                            purple,
                          ),
                        ),
                        childCount: filteredProviders.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color orange) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() {}),
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search service, provider...',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.white24,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubCategoriesGrid() {
    final subs = _getSubCategories();
    final crossAxisCount = subs.length == 8 ? 4 : 5;

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 10,
        childAspectRatio: subs.length == 8 ? 0.8 : 0.7,
      ),
      itemCount: subs.length,
      itemBuilder: (context, index) {
        final sub = subs[index];
        final isSelected = _selectedSubCategory == sub['name'];
        final Color accent = sub['color'];
        return GestureDetector(
          onTap: () {
            setState(() => _selectedSubCategory = sub['name']);
            HapticFeedback.lightImpact();
          },
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent.withAlpha(38)
                      : const Color(0xFF12121A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? accent : Colors.white.withAlpha(20),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    sub['icon'],
                    color: isSelected ? accent : Colors.white54,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sub['name'].toUpperCase(),
                style: GoogleFonts.rajdhani(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProviderCard(
    Map<String, dynamic> provider,
    Color orange,
    Color purple,
  ) {
    final String imgPath = provider['img'];
    final bool isNetworkImg = imgPath.startsWith('http');
    final bool isAvailable =
        provider['full_partner_data']['isAcceptingAppointments'] ?? true;

    Widget cardContent = Column(
      children: [
        Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: isNetworkImg
                      ? CachedNetworkImageProvider(imgPath) as ImageProvider
                      : AssetImage(imgPath),
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: Colors.white.withAlpha(25)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider['name'].toUpperCase(),
                    style: GoogleFonts.rajdhani(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    provider['info'],
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Specialization Badge
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? orange.withAlpha(30)
                                : Colors.white.withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAvailable
                                  ? orange.withAlpha(80)
                                  : Colors.white24,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                color: isAvailable ? orange : Colors.white38,
                                size: 12,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  provider['sub'].toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.rajdhani(
                                    color: isAvailable
                                        ? Colors.white
                                        : Colors.white38,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFC107),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${provider['rating']}',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFFC107),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 10, color: Colors.white10),
                      const SizedBox(width: 12),
                      Text(
                        provider['exp'],
                        style: GoogleFonts.rajdhani(
                          color: orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 10, color: Colors.white10),
                      const SizedBox(width: 12),
                      Icon(Icons.location_on_rounded, color: purple, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        provider['dist'],
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BOOKING FEE',
                  style: GoogleFonts.rajdhani(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '₹${provider['fee'] + PriceCalculator.FIXED_MARKUP.toInt()}',
                  style: GoogleFonts.orbitron(
                    color: isAvailable ? Colors.white : Colors.white38,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (!isAvailable)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'CURRENTLY NOT AVAILABLE',
                  style: GoogleFonts.rajdhani(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceDetailScreenV2(
                        service: provider,
                        category: widget.category,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5F00), Color(0xFFFF8A00)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: orange.withAlpha(76),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        'BOOK NOW',
                        style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    if (!isAvailable) {
      cardContent = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: cardContent,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12121A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isAvailable
              ? orange.withAlpha(51)
              : Colors.white.withAlpha(20),
        ),
      ),
      child: cardContent,
    );
  }
}
