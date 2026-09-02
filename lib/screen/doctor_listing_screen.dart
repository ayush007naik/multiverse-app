import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/premium_ui_widgets.dart';
import 'doctor_detail_screen.dart';

class DoctorListingScreen extends StatefulWidget {
  const DoctorListingScreen({super.key});

  @override
  State<DoctorListingScreen> createState() => _DoctorListingScreenState();
}

class _DoctorListingScreenState extends State<DoctorListingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSpecialty = 'General';

  final List<Map<String, dynamic>> _specialties = [
    {
      'name': 'General',
      'icon': Icons.medical_services_outlined,
      'color': Colors.blue,
    },
    {
      'name': 'Orthopedic',
      'icon': Icons.accessibility_new_rounded,
      'color': Colors.green,
    },
    {
      'name': 'Pediatric',
      'icon': Icons.child_care_rounded,
      'color': Colors.orange,
    },
    {
      'name': 'Gynae',
      'icon': Icons.pregnant_woman_rounded,
      'color': Colors.pink,
    },
    {
      'name': 'Skin',
      'icon': Icons.face_retouching_natural_rounded,
      'color': Colors.purple,
    },
    {'name': 'ENT', 'icon': Icons.hearing_rounded, 'color': Colors.teal},
    {'name': 'Eye', 'icon': Icons.visibility_rounded, 'color': Colors.red},
    {
      'name': 'Cardiac',
      'icon': Icons.favorite_outline_rounded,
      'color': Colors.redAccent,
    },
    {
      'name': 'Neuro',
      'icon': Icons.psychology_outlined,
      'color': Colors.indigo,
    },
    {
      'name': 'Physio',
      'icon': Icons.fitness_center_rounded,
      'color': Colors.cyan,
    },
  ];

  final List<Map<String, dynamic>> _allDoctors = [
    {
      'name': 'Dr. Sarah Johnson',
      'qualification': 'MBBS, MD',
      'specialty': 'General',
      'experience': '12 yrs',
      'rating': 4.9,
      'reviews': 124,
      'fee': 500,
      'distance': '1.2 km',
      'image': 'assets/doctor.png',
      'isAvailableToday': true,
    },
    {
      'name': 'Dr. Michael Chen',
      'qualification': 'MBBS, MS',
      'specialty': 'Orthopedic',
      'experience': '15 yrs',
      'rating': 4.8,
      'reviews': 98,
      'fee': 600,
      'distance': '2.5 km',
      'image': 'assets/doctor.png',
      'isAvailableToday': true,
    },
    {
      'name': 'Dr. Emily Brown',
      'qualification': 'MBBS, DCH',
      'specialty': 'Pediatric',
      'experience': '8 yrs',
      'rating': 4.7,
      'reviews': 156,
      'fee': 450,
      'distance': '3.1 km',
      'image': 'assets/doctor.png',
      'isAvailableToday': false,
    },
    {
      'name': 'Dr. Robert Wilson',
      'qualification': 'MBBS, MD',
      'specialty': 'Cardiac',
      'experience': '20 yrs',
      'rating': 5.0,
      'reviews': 210,
      'fee': 800,
      'distance': '0.8 km',
      'image': 'assets/doctor.png',
      'isAvailableToday': true,
    },
    {
      'name': 'Dr. Jane Smith',
      'qualification': 'MD, DNB',
      'specialty': 'General',
      'experience': '10 yrs',
      'rating': 4.6,
      'reviews': 85,
      'fee': 400,
      'distance': '1.5 km',
      'image': 'assets/doctor.png',
      'isAvailableToday': true,
    },
  ];

  List<Map<String, dynamic>> get _filteredDoctors {
    return _allDoctors
        .where((doc) => doc['specialty'] == _selectedSpecialty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.black,
            floating: true,
            pinned: true,
            elevation: 0,
            toolbarHeight: 56,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Doctors',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Image.asset(
                  'assets/logo.png',
                  height: 28,
                  width: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildSpecialtiesGrid(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Top Rated Doctors'),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return FadeSlideAnimation(
                  child: _buildPremiumDoctorCard(_filteredDoctors[index]),
                );
              }, childCount: _filteredDoctors.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Colors.white38,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search doctor, clinic...',
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
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialtiesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specialties',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 0.65,
          ),
          itemCount: _specialties.length,
          itemBuilder: (context, index) {
            final specialty = _specialties[index];
            final isSelected = _selectedSpecialty == specialty['name'];
            return GestureDetector(
              onTap: () {
                setState(() => _selectedSpecialty = specialty['name']);
                HapticFeedback.selectionClick();
              },
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? RadialGradient(
                              colors: [
                                specialty['color'].withValues(alpha: 0.3),
                                specialty['color'].withValues(alpha: 0.05),
                              ],
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFF161618),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? specialty['color']
                            : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: specialty['color'].withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 15,
                                spreadRadius: -2,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Icon(
                        specialty['icon'],
                        color: isSelected
                            ? specialty['color']
                            : specialty['color'].withValues(alpha: 0.6),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    specialty['name'],
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 9.5,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPremiumDoctorCard(Map<String, dynamic> doctor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          const BoxShadow(
            color: Colors.black,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: AssetImage(doctor['image']),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            doctor['name'],
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFC107,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFC107),
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${doctor['rating']}',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFFC107),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doctor['qualification'],
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doctor['specialty'],
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFF7A1A),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSmallTag(
                          Icons.work_history_rounded,
                          doctor['experience'],
                        ),
                        const SizedBox(width: 12),
                        _buildSmallTag(
                          Icons.location_on_rounded,
                          doctor['distance'],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consultation Fee',
                    style: GoogleFonts.poppins(
                      color: Colors.white38,
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    '₹${doctor['fee']}',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              if (doctor['isAvailableToday'])
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Available Today',
                        style: GoogleFonts.poppins(
                          color: Colors.green,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DoctorDetailScreen(doctor: doctor),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9D00), Color(0xFFFF3D00)],
                    ), // More vibrant orange-red
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7A1A).withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Book',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTag(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white24, size: 13),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
