import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import 'package:google_fonts/google_fonts.dart';
import '../caches/banner_cache.dart';
import '../services/auth_flow_service.dart';
import '../services/logout_service.dart';
import '../services/otp_auth_service.dart';
import '../utils/image_precache.dart';
import 'login_screen.dart';
import 'enhanced_home_screen.dart';
import 'signup/customer_signup_screen.dart';

class CyberpunkSplashScreen extends StatefulWidget {
  const CyberpunkSplashScreen({super.key});

  @override
  State<CyberpunkSplashScreen> createState() => _CyberpunkSplashScreenState();
}

class _CyberpunkSplashScreenState extends State<CyberpunkSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _shimmerController;
  late AnimationController _loadingController;
  late AnimationController _logoPulseController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _loadingProgress;
  late Animation<double> _logoScaleAnimation;

  final AuthFlowService _authFlowService = AuthFlowService();
  final OtpAuthService _otpAuthService = OtpAuthService();

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _logoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _loadingProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );

    _logoScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _logoPulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _loadingController.forward().then((_) => _navigateToNext());
    _precacheLoginBanners();
  }

  Future<void> _precacheLoginBanners() async {
    try {
      List<String> urls = [];

      // Get from BannerCache first
      final cached = BannerCache.data;
      if (cached != null) {
        for (final b in cached) {
          final pos = b['position'];
          final img = b['imageUrl'] ?? b['image'] ?? b['url'];
          if (img != null &&
              img is String &&
              img.isNotEmpty &&
              (pos == null || pos == 'login')) {
            urls.add(img);
          }
        }
      }

      // Fallback: fetch from Firestore
      if (urls.isEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('banners')
            .where('isActive', isEqualTo: true)
            .get()
            .timeout(const Duration(seconds: 3));
        for (final doc in snap.docs) {
          final data = doc.data();
          final pos = data['position'];
          final img = data['imageUrl'] ?? data['image'] ?? data['url'];
          if (img != null &&
              img is String &&
              img.isNotEmpty &&
              (pos == null || pos == 'login')) {
            urls.add(img);
          }
        }
        if (urls.isNotEmpty) {
          // Store in the same normalized shape the app uses everywhere else
          // (createdAt as epoch millis), so cache consumers that sort by
          // `createdAt as int` never hit a raw Firestore Timestamp.
          BannerCache.set(snap.docs.map((d) {
            final data = d.data();
            return <String, dynamic>{
              'imageUrl': data['imageUrl'] ?? data['image'] ?? '',
              'title': data['title'] ?? '',
              'subtitle': data['subtitle'] ?? '',
              'actionUrl': data['actionUrl'] ?? '',
              'priority': data['priority'] ?? 999,
              'position': data['position'] ?? 'home',
              'createdAt': (data['createdAt'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0,
            };
          }).toList());
        }
      }

      // Precache into memory + disk via the shared AppCacheManager.
      // Parallel + context-free so it keeps warming even after the splash is
      // disposed and navigation to login has already started.
      await precacheNetworkImages(urls, maxWidth: 800);
    } catch (_) {}
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;

    try {
      final hasSession = await _otpAuthService.hasActiveSession();
      if (!mounted) return;

      if (!hasSession) {
        _goToLogin();
        return;
      }

      final uid = await _otpAuthService.getSavedUid();
      if (!mounted) return;

      if (uid == null || uid.isEmpty) {
        await _otpAuthService.clearUserSession();
        if (mounted) _goToLogin();
      } else {
        await _checkUserRole(uid);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EnhancedHomeScreen()),
        );
      }
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _checkUserRole(String uid) async {
    try {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (!userData.exists) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerSignupScreen()),
        );
        return;
      }

      final role = userData.data()?['role'] as String? ?? 'Customer';
      final isBlocked = userData.data()?['isBlocked'] ?? false;

      if (isBlocked) {
        _showBlockedDialog();
        return;
      }

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              _authFlowService.destinationForRole(role),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EnhancedHomeScreen()),
        );
      }
    }
  }

  void _showBlockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Account Blocked',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'Your account has been blocked.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await LogoutService.signOutOnly();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('OK', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shimmerController.dispose();
    _loadingController.dispose();
    _logoPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Color(0xFF1A0B2E), // Dark Cyberpunk Purple
              Colors.black,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. LOGO with Pulse Animation
                ScaleTransition(
                  scale: _logoScaleAnimation,
                  child: Image.asset(
                    'assets/logo.png',
                    width: 150,
                    height: 150,
                  ),
                ),
                const SizedBox(height: 30),

                // 2. SHINING TEXT (Ensure Single Line)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              colors: const [
                                Color(0xFFFF7A1A),
                                Color(0xFF6A26E3),
                                Color(0xFFFF7A1A),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              transform: GradientRotation(
                                _shimmerController.value * 2 * 3.14159,
                              ),
                            ).createShader(bounds);
                          },
                          child: Text(
                            'MULTIVERSE',
                            maxLines: 1,
                            style: GoogleFonts.orbitron(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 10,
                              shadows: [
                                Shadow(
                                  color: const Color(
                                    0xFFFF7A1A,
                                  ).withValues(alpha: 0.6),
                                  blurRadius: 15,
                                ),
                                Shadow(
                                  color: const Color(
                                    0xFF6A26E3,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 30,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 100),

                // 3. LOADING SCREEN (PROGRESS BAR)
                Container(
                  width: 200,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AnimatedBuilder(
                    animation: _loadingProgress,
                    builder: (context, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _loadingProgress.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6A26E3), // Purple
                                Color(0xFFFF7A1A), // Orange
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF6A26E3,
                                ).withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
