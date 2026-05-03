// 📁 lib/screens/splash_screen.dart
// ✅ Clean Splash Screen - 2 seconds then navigate to Home

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_flow_service.dart';
import '../services/otp_auth_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  final AuthFlowService _authFlowService = AuthFlowService();
  final OtpAuthService _otpAuthService = OtpAuthService();

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 [SplashScreen] Starting splash screen');

    // Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnim = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();

    // Navigate after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      debugPrint('⏰ [SplashScreen] 2 seconds elapsed, navigating');
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) {
      debugPrint('⚠️ [SplashScreen] Widget not mounted, skipping navigation');
      return;
    }

    debugPrint('🔄 [SplashScreen] Checking auth state');

    try {
      // Check if user has active session
      final hasSession = await _otpAuthService.hasActiveSession();
      
      if (!mounted) return;

      if (!hasSession) {
        // No active session - go to login
        debugPrint('🔓 [SplashScreen] No active session, navigating to Login');
        _goToLogin();
        return;
      }

      // Has session - check Firebase auth
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        // Session exists but no Firebase user - clear session and go to login
        debugPrint('⚠️ [SplashScreen] Session exists but no Firebase user');
        await _otpAuthService.clearUserSession();
        if (mounted) _goToLogin();
      } else {
        // User exists - check role and navigate
        debugPrint('✅ [SplashScreen] User found, checking role');
        await _checkUserRoleAndNavigate(user.uid);
      }
    } catch (e) {
      debugPrint('❌ [SplashScreen] Error: $e, navigating to Home as fallback');
      // On any error, go to HomeScreen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<void> _checkUserRoleAndNavigate(String uid) async {
    try {
      debugPrint('🔍 [SplashScreen] Fetching user role');

      final userData =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!mounted) return;

      if (!userData.exists) {
        debugPrint('⚠️ [SplashScreen] User data not found, going to Home');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return;
      }

      final role = userData.data()?['role'] as String? ?? 'Customer';
      final isBlocked = userData.data()?['isBlocked'] ?? false;

      debugPrint('👤 [SplashScreen] Role: $role, Blocked: $isBlocked');

      if (isBlocked) {
        debugPrint('🚫 [SplashScreen] User blocked');
        _showBlockedDialog();
        return;
      }

      debugPrint('🎯 [SplashScreen] Navigating to $role screen');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _authFlowService.destinationForRole(role),
        ),
      );
    } catch (e) {
      debugPrint('❌ [SplashScreen] Role check failed: $e');
      // Fallback to HomeScreen on error
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
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
        title: const Text("Account Blocked",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
            "Your account has been blocked by the administrator. Please contact support.",
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("OK", style: TextStyle(color: Color(0xFFFF4D4F))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF0D0D0D),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔮 App Logo with Hero for seamless transition
                  Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/logo.png',
                      width: 150,
                      height: 150,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 🔤 App Name
                  const Text(
                    'MULTIVERSE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),

                  const SizedBox(height: 60),

                  // ⏳ Loading indicator
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF4D4F), // Premium Red Accent
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
