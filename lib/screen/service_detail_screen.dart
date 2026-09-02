import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'service_booking_form_screen.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> service;

  const ServiceDetailScreen({super.key, required this.service});

  // Service-specific data
  Map<String, dynamic> _getServiceData() {
    final String name = service['name'] ?? '';

    // Service-specific descriptions and inclusions
    final Map<String, dynamic> serviceData = {
      'Salon & Spa': {
        'tagline': 'Premium beauty & wellness treatments',
        'description':
            'Experience luxury salon and spa services at your doorstep. Our certified beauty professionals use premium products and advanced techniques to rejuvenate your mind and body. From relaxing massages to professional styling, we deliver spa-quality results in the comfort of your home.',
        'inclusions': [
          'Certified beauty therapists',
          'Premium skincare products',
          'Relaxing massage treatments',
          'Professional hair styling',
          'Hygiene-first equipment',
        ],
      },
      'Plumbing': {
        'tagline': 'Expert plumbing solutions 24/7',
        'description':
            'Professional plumbing services for all your home needs. Our licensed plumbers handle everything from leak repairs to complete installations with precision and care. We use high-quality materials and provide warranty on all services to ensure lasting solutions.',
        'inclusions': [
          'Licensed plumbing experts',
          'Leak detection & repair',
          'Pipe installation & replacement',
          'Drain cleaning services',
          '90-day service warranty',
        ],
      },
      'Electrician': {
        'tagline': 'Safe & reliable electrical services',
        'description':
            'Certified electricians providing safe and efficient electrical solutions for your home. From simple repairs to complex installations, we ensure all work meets safety standards. Our experts handle wiring, fixture installation, and electrical troubleshooting with professionalism.',
        'inclusions': [
          'Certified electricians',
          'Wiring & rewiring services',
          'Fixture installation',
          'Electrical safety checks',
          'Emergency repair support',
        ],
      },
      'Cleaning': {
        'tagline': 'Deep cleaning for a healthier home',
        'description':
            'Transform your space with our comprehensive cleaning services. Our trained professionals use eco-friendly products and advanced equipment to deliver spotless results. From deep cleaning to regular maintenance, we ensure every corner of your home shines.',
        'inclusions': [
          'Trained cleaning professionals',
          'Eco-friendly cleaning products',
          'Deep & surface cleaning',
          'Carpet & upholstery care',
          'Satisfaction guarantee',
        ],
      },
      'AC Service': {
        'tagline': 'Keep your AC running perfectly',
        'description':
            'Expert AC repair, service, and installation services to keep you comfortable year-round. Our certified technicians diagnose and fix all AC issues quickly. We provide thorough cleaning, gas refilling, and preventive maintenance to extend your AC\'s lifespan.',
        'inclusions': [
          'Certified AC technicians',
          'Complete AC servicing',
          'Gas refilling & leak repair',
          'Compressor diagnostics',
          '6-month service warranty',
        ],
      },
      'Home Paint': {
        'tagline': 'Transform your walls with expert painters',
        'description':
            'Professional painting services to refresh and beautify your home. Our skilled painters deliver flawless finishes using premium quality paints. From single rooms to complete homes, we handle interior and exterior painting with attention to every detail.',
        'inclusions': [
          'Experienced painters',
          'Premium quality paints',
          'Surface preparation & priming',
          'Texture & design options',
          'Clean work guarantee',
        ],
      },
    };

    return serviceData[name] ??
        {
          'tagline': 'Professional home services',
          'description':
              'Expert ${name.toLowerCase()} services delivered at your doorstep with quality and care.',
          'inclusions': [
            'Verified professionals',
            'Quality service guarantee',
            'Transparent pricing',
            'Post-service support',
          ],
        };
  }

  @override
  Widget build(BuildContext context) {
    final String name = service['name'] ?? 'Service';
    final String image = service['image'] ?? '';
    final Color neonColor =
        service['neonColor'] ?? service['color'] ?? const Color(0xFFFF7A1A);
    final serviceData = _getServiceData();
    final String tagline = serviceData['tagline'];
    final String description = serviceData['description'];
    final List<String> inclusions = List<String>.from(
      serviceData['inclusions'],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: Stack(
        children: [
          // Scrollable Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero Image Section
              SliverAppBar(
                expandedHeight: 320,
                pinned: false,
                floating: false,
                backgroundColor: const Color(0xFF0A0A0D),
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Hero Image
                      if (image.isNotEmpty)
                        Image.asset(
                          image,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF1A1A1A),
                              child: Center(
                                child: Icon(
                                  service['icon'] ?? Icons.settings_rounded,
                                  size: 80,
                                  color: neonColor.withValues(alpha: 0.3),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          color: const Color(0xFF1A1A1A),
                          child: Center(
                            child: Icon(
                              service['icon'] ?? Icons.settings_rounded,
                              size: 80,
                              color: neonColor.withValues(alpha: 0.3),
                            ),
                          ),
                        ),

                      // Dark Gradient Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                              Colors.black.withValues(alpha: 0.95),
                            ],
                            stops: const [0.0, 0.3, 0.6, 1.0],
                          ),
                        ),
                      ),

                      // Service Title Overlay
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.9),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tagline,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating Row - Glassmorphism Container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Star Rating
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '4.8',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '120+ Reviews',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Verified Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: neonColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: neonColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    color: neonColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified',
                                    style: GoogleFonts.poppins(
                                      color: neonColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // About Service
                      Text(
                        'ABOUT SERVICE',
                        style: GoogleFonts.orbitron(
                          color: neonColor.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                          height: 1.7,
                          letterSpacing: 0.2,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // What's Included
                      Text(
                        'WHAT\'S INCLUDED',
                        style: GoogleFonts.orbitron(
                          color: neonColor.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...inclusions.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: neonColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: neonColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Fixed Bottom Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0A0A0D).withValues(alpha: 0.9),
                    const Color(0xFF0A0A0D),
                  ],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: neonColor.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ServiceBookingFormScreen(service: service),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: neonColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'BOOK NOW',
                    style: GoogleFonts.orbitron(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
