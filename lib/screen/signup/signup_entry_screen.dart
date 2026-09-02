import 'package:flutter/material.dart';
import '../../widgets/premium_ui_widgets.dart';
import '../login_screen.dart';
import 'customer_signup_screen.dart';
import 'provider_signup_screen.dart';

class SignupEntryScreen extends StatelessWidget {
  const SignupEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color neonOrange = Color(0xFFFF5722);
    final size = MediaQuery.of(context).size;
    final double posterHeight = size.height * 0.58; // Reserved 58% for poster

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 1. POSTER IMAGE SECTION - Responsive height (55-60% range)
          FadeSlideAnimation(
            delay: const Duration(milliseconds: 100),
            child: Container(
              width: size.width,
              height: posterHeight,
              decoration: const BoxDecoration(color: Colors.black),
              child: Center(
                child: Transform.translate(
                  offset: const Offset(
                    0,
                    30,
                  ), // Shifted down for full branding visibility
                  child: Transform.scale(
                    scale: 1.15, // 15% Zoom for premium feel
                    child: Image.asset(
                      'assets/images/signup_poster.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. UI SECTION - Premium Signup Options (Occupies remaining ~42%)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(color: Colors.black),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
                child: Column(
                  children: [
                    SizedBox(
                      height: size.height * 0.02,
                    ), // Balanced top spacing
                    // Login Link with Neon Glow
                    FadeSlideAnimation(
                      delay: const Duration(milliseconds: 300),
                      child: GestureDetector(
                        onTap: () => _navigateTo(context, const LoginScreen()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                              children: [
                                TextSpan(text: "Already have an account? "),
                                TextSpan(
                                  text: "Login",
                                  style: TextStyle(
                                    color: neonOrange,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(color: neonOrange, blurRadius: 15),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: size.height * 0.035), // Responsive gap
                    // Signup Option: Customer
                    FadeSlideAnimation(
                      delay: const Duration(milliseconds: 500),
                      child: _buildSignupCard(
                        context: context,
                        title: "Signup as Customer",
                        subtitle: "Shop, book services & explore more",
                        icon: Icons.person_add_alt_1_rounded,
                        onTap: () =>
                            _navigateTo(context, const CustomerSignupScreen()),
                      ),
                    ),

                    SizedBox(height: size.height * 0.015),

                    // Signup Option: Service Provider
                    FadeSlideAnimation(
                      delay: const Duration(milliseconds: 700),
                      child: _buildSignupCard(
                        context: context,
                        title: "Signup as Service Provider",
                        subtitle:
                            "(Retailer, Delivery Person, Real Estate Agent,Etc)",
                        icon: Icons.storefront_rounded,
                        onTap: () =>
                            _navigateTo(context, const ProviderSignupScreen()),
                        subtitleFontSize: 11.5,
                      ),
                    ),

                    // Proper bottom spacing for Pixel/modern devices
                    SizedBox(height: size.height * 0.05),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Professional page transition (Fade + Slide)
  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.05);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(tween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  /// Custom Dark Glassmorphism Card Style with soft orange glow
  Widget _buildSignupCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    double subtitleFontSize = 13,
  }) {
    const Color neonOrange = Color(0xFFFF5722);

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        borderColor: neonOrange.withValues(alpha: 0.35),
        shadows: [
          BoxShadow(
            color: neonOrange.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: -10,
          ),
        ],
        child: Row(
          children: [
            // Left Side: Orange Icon with Glow
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: neonOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: neonOrange.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: neonOrange, size: 28),
            ),
            const SizedBox(width: 16),
            // Middle: White Heading & Grey Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        color: const Color(0xFF9E9E9E),
                        fontSize: subtitleFontSize,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Right Side: Minimal Arrow
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white24,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
