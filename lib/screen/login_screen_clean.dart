import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:db_compat/db_compat.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_flow_service.dart';
import '../services/otp_auth_service.dart';
import '../services/security_tracking_service.dart';
import '../caches/banner_cache.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../widgets/premium_ui_widgets.dart';
import 'signup/customer_signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isLoading = false;
  bool _otpSent = false;
  bool _isKeyboardOpen = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthFlowService _authFlowService = AuthFlowService();
  final OtpAuthService _otpAuthService = OtpAuthService();

  late AnimationController _shimmerController;
  late AnimationController _keyboardTransitionController;
  List<String> _sliderImages = [];
  StreamSubscription? _bannerSub;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _keyboardTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _phoneFocusNode.addListener(_onFocusChange);
    _otpFocusNode.addListener(_onFocusChange);

    // ✅ Load from local cache immediately for 0.1s visual load
    final cached = BannerCache.data;
    if (cached != null && cached.isNotEmpty) {
      final urls = cached
          .where((b) => b['position'] == 'login' && b['isActive'] == true)
          .map((b) => (b['imageUrl'] ?? '').toString())
          .where((url) => url.isNotEmpty)
          .toList();
      if (urls.isNotEmpty) {
        _sliderImages = urls;
        // Pre-cache immediately for memory stability
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final url in urls) {
            precacheImage(CachedNetworkImageProvider(url, maxWidth: 800), context);
          }
        });
      }
    }

    _listenBannerImages();
  }

  void _listenBannerImages() {
    _bannerSub = FirebaseFirestore.instance
        .collection('banners')
        .where('position', isEqualTo: 'login')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final pa = (a.data()['priority'] ?? 0) as num;
        final pb = (b.data()['priority'] ?? 0) as num;
        return pa.compareTo(pb);
      });
      final urls =
          docs
              .map((doc) => (doc.data()['imageUrl'] ?? '').toString())
              .where((url) => url.isNotEmpty)
              .toList();

      if (mounted && !listEquals(_sliderImages, urls)) {
        setState(() => _sliderImages = urls);
        // ✅ Pre-cache for the NEXT session
        for (final url in urls) {
          precacheImage(CachedNetworkImageProvider(url, maxWidth: 800), context);
        }
      }
    });
  }

  void _onFocusChange() {
    final isFocused = _phoneFocusNode.hasFocus || _otpFocusNode.hasFocus;
    if (isFocused != _isKeyboardOpen) {
      setState(() {
        _isKeyboardOpen = isFocused;
      });

      if (isFocused) {
        _keyboardTransitionController.forward();
      } else {
        _keyboardTransitionController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _bannerSub?.cancel();
    _shimmerController.dispose();
    _keyboardTransitionController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.removeListener(_onFocusChange);
    _otpFocusNode.removeListener(_onFocusChange);
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _normalizedPhone() {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final local = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
    return '+91$local';
  }

  Future<void> _sendOTP() async {
    final formattedPhone = _normalizedPhone();
    if (!RegExp(r'^\+91[1-9]\d{9}$').hasMatch(formattedPhone)) {
      _showError('Please enter a valid 10-digit phone number');
      return;
    }
    setState(() => _isLoading = true);
    final result = await _otpAuthService.sendOtp(
      phone: formattedPhone,
      mode: 'login',
    );
    if (!mounted) return;
    if (result['success']) {
      setState(() {
        _otpSent = true;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (result['error'] == 'not-found') {
        _numberNotRegistered();
      } else {
        _showError(result['message']);
      }
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length < 6) {
      _showError('Please enter 6-digit OTP');
      return;
    }
    setState(() => _isLoading = true);
    final formattedPhone = _normalizedPhone();
    final result = await _otpAuthService.verifyOtp(
      phone: formattedPhone,
      enteredOtp: otp,
      mode: 'login',
    );
    if (!mounted) return;
    if (result['success']) {
      try {
        await _auth.signInWithCustomToken(result['customToken']);
        await _handlePostVerification(
          formattedPhone,
          uid: result['uid'],
          isNewUser: result['isNewUser'],
          roles: List<String>.from(result['roles']),
        );
        SecurityTrackingService.recordLogin(uid: result['uid'], phone: formattedPhone, success: true);
        SecurityTrackingService.recordDevice(uid: result['uid']);
        SecurityTrackingService.recordActivity(uid: result['uid'], activity: 'Logged in');
      } catch (e) {
        SecurityTrackingService.recordLogin(uid: _auth.currentUser?.uid ?? '', phone: formattedPhone, success: false);
        setState(() => _isLoading = false);
        _showError('Sign-in failed. Please try again');
      }
    } else {
      SecurityTrackingService.recordLogin(uid: _auth.currentUser?.uid ?? '', phone: formattedPhone, success: false);
      setState(() => _isLoading = false);
      if (result['error'] == 'not-found') {
        _numberNotRegistered();
      } else {
        _showError(result['message']);
      }
    }
  }

  Future<void> _handlePostVerification(
    String phoneNumber, {
    required String uid,
    required bool isNewUser,
    required List<String> roles,
  }) async {
    try {
      // Defense in depth: the server now blocks new accounts on login, but if
      // this is ever hit, never auto-create a profile for an unregistered
      // number — send them to sign up instead.
      if (isNewUser) {
        await _auth.signOut();
        if (!mounted) return;
        setState(() => _isLoading = false);
        _numberNotRegistered();
        return;
      }

      if (!mounted) return;
      final role = roles.isNotEmpty ? roles.last : 'customer';
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => _authFlowService.destinationForRole(role),
        ),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error: $e');
    }
  }

  /// Tells the user their number isn't registered and routes them to signup.
  void _numberNotRegistered() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('This number is not registered. Please sign up first.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'SIGN UP',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerSignupScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Container(color: Colors.black),

            Positioned(
              top: -50,
              right: -50,
              child: _BlurredCircle(
                color: const Color(0xFF6A26E3).withValues(alpha: 0.12),
                size: 220,
              ),
            ),

            Column(
              children: [
                // Banner - FULL WIDTH, AGGRESSIVELY MINIMIZES
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: _isKeyboardOpen
                      ? screenHeight *
                            0.35 // Minimized (35%)
                      : screenHeight * 0.65, // Full cinematic (65%)
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_sliderImages.isEmpty)
                        Container(color: const Color(0xFF0A0A0D))
                      else
                        CarouselSlider(
                          options: CarouselOptions(
                            height: double.infinity,
                            viewportFraction: 1.0,
                            autoPlay: !_isKeyboardOpen,
                            autoPlayInterval: const Duration(seconds: 4),
                            autoPlayAnimationDuration: const Duration(
                              milliseconds: 1200,
                            ),
                            autoPlayCurve: Curves.easeInOutCubic,
                            enableInfiniteScroll: true,
                          ),
                          items: _sliderImages.map((imageUrl) {
                            return CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              width: double.infinity,
                              height: double.infinity,
                              maxWidthDiskCache: 800,
                              memCacheWidth: 800,
                              fadeOutDuration: Duration.zero, // ✅ Instant switch
                              fadeInDuration: Duration.zero,  // ✅ Instant switch
                              placeholder: (context, url) =>
                                  Container(color: Colors.black),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFF0A0A0D),
                                child: const Center(
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.white24,
                                    size: 48,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                              Colors.black.withValues(alpha: 0.95),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Login form
                Expanded(
                  child: SingleChildScrollView(
                    physics: keyboardHeight > 0
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: _isKeyboardOpen ? 8 : 12,
                      bottom: keyboardHeight > 0 ? 16 : 32,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            scale: _isKeyboardOpen ? 0.65 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            child: _buildGlowingLogo(),
                          ),

                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: _isKeyboardOpen ? 4 : 8,
                          ),

                          AnimatedOpacity(
                            opacity: _isKeyboardOpen ? 0.0 : 0.6,
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              "THE FUTURE OF SHOPPING IS HERE",
                              style: GoogleFonts.orbitron(
                                color: Colors.white,
                                fontSize: 9,
                                letterSpacing: 2.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: _isKeyboardOpen ? 12 : 20,
                          ),

                          FadeSlideAnimation(
                            delay: const Duration(milliseconds: 150),
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: GlassCard(
                                margin: EdgeInsets.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 15,
                                ),
                                borderRadius: 20,
                                opacity: 0.1,
                                blur: 25,
                                borderColor: Colors.white.withValues(
                                  alpha: 0.06,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _otpSent
                                          ? "VERIFY CODE"
                                          : "ENTER PHONE NUMBER",
                                      style: GoogleFonts.orbitron(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    if (!_otpSent)
                                      _buildNeonInput(
                                        controller: _phoneController,
                                        focusNode: _phoneFocusNode,
                                        hint: "Mobile Number",
                                        icon: Icons.phone_iphone_rounded,
                                        keyboardType: TextInputType.phone,
                                        prefixText: '+91',
                                      )
                                    else
                                      _buildNeonInput(
                                        controller: _otpController,
                                        focusNode: _otpFocusNode,
                                        hint: "• • • • • •",
                                        icon: Icons.lock_open_rounded,
                                        keyboardType: TextInputType.number,
                                        isOtp: true,
                                      ),

                                    const SizedBox(height: 14),

                                    NeonButton(
                                      text: _otpSent
                                          ? "VERIFY ACCESS"
                                          : "GET STARTED",
                                      height: 44,
                                      onPressed: _isLoading
                                          ? null
                                          : (_otpSent ? _verifyOTP : _sendOTP),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: _isKeyboardOpen ? 8 : 18,
                          ),

                          FadeSlideAnimation(
                            delay: const Duration(milliseconds: 300),
                            child: _buildSignUpLink(),
                          ),

                          if (keyboardHeight > 0) const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5722)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingLogo() {
    return AnimatedBuilder(
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
              stops: [0.0, 0.5 * (1.0 + _shimmerController.value), 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds);
          },
          child: Text(
            'MULTIVERSE',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 4.0,
              shadows: [
                Shadow(
                  color: const Color(0xFFFF7A1A).withValues(alpha: 0.6),
                  blurRadius: 15,
                ),
                Shadow(
                  color: const Color(0xFF6A26E3).withValues(alpha: 0.4),
                  blurRadius: 30,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNeonInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    bool isOtp = false,
    String? prefixText,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF7A1A).withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textAlign: isOtp ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: isOtp ? 17 : 13.5,
            letterSpacing: isOtp ? 6 : 0.5,
            fontWeight: isOtp ? FontWeight.bold : FontWeight.w500,
          ),
          cursorColor: const Color(0xFFFF7A1A),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 12.5,
              letterSpacing: 0,
            ),
            prefixIcon: isOtp
                ? null
                : Icon(icon, color: const Color(0xFFFF7A1A), size: 17),
            prefixText: prefixText,
            prefixStyle: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerSignupScreen()),
      ),
      child: RichText(
        text: TextSpan(
          text: "New to Multiverse? ",
          style: GoogleFonts.poppins(
            color: Colors.white38,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
          children: [
            TextSpan(
              text: "Sign Up",
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF7A1A),
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: const Color(0xFFFF7A1A).withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlurredCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _BlurredCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}
