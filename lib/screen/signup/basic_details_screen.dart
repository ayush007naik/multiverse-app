import 'dart:async';
import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/logging_service.dart';
import '../login_screen.dart';
import '../../caches/banner_cache.dart';
import '../../services/otp_auth_service.dart';
import 'otp_verification_screen.dart';

class BasicDetailsScreen extends StatefulWidget {
  final String signupType;

  const BasicDetailsScreen({super.key, required this.signupType});

  @override
  State<BasicDetailsScreen> createState() => _BasicDetailsScreenState();
}

class _BasicDetailsScreenState extends State<BasicDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final OtpAuthService _otpService = OtpAuthService();

  bool _isSendingOtp = false;

  List<String> _bannerImages = [];
  StreamSubscription? _bannerSub;
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _currentBannerPage = 0;

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();

  bool _isNameFocused = false;
  bool _isEmailFocused = false;
  bool _isPhoneFocused = false;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(
      () => setState(() => _isNameFocused = _nameFocusNode.hasFocus),
    );
    _emailFocusNode.addListener(
      () => setState(() => _isEmailFocused = _emailFocusNode.hasFocus),
    );
    _phoneFocusNode.addListener(
      () => setState(() => _isPhoneFocused = _phoneFocusNode.hasFocus),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _listenBannerImages();
  }

  void _startBannerAutoPlay() {
    _bannerTimer?.cancel();
    if (_bannerImages.length <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentBannerPage + 1) % _bannerImages.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _listenBannerImages() {
    // 1. INSTANT LOAD from cache
    final cached = BannerCache.data;
    if (cached != null && cached.isNotEmpty) {
      final signupBanners = cached
          .where((b) => (b['position'] as String?) == 'signup')
          .map((b) => (b['imageUrl'] ?? '').toString())
          .where((url) => url.isNotEmpty)
          .toList();
      if (signupBanners.isNotEmpty && mounted) {
        setState(() => _bannerImages = signupBanners);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _startBannerAutoPlay(),
        );
      }
    }

    // 2. LIVE Firestore stream for updates
    _bannerSub = FirebaseFirestore.instance
        .collection('banners')
        .where('position', isEqualTo: 'signup')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          final docs = snapshot.docs.toList();
          docs.sort((a, b) {
            final pa = (a.data()['priority'] ?? 0) as num;
            final pb = (b.data()['priority'] ?? 0) as num;
            return pa.compareTo(pb);
          });
          final urls = docs
              .map((doc) {
                final data = doc.data();
                return (data['imageUrl'] ?? '').toString();
              })
              .where((url) => url.isNotEmpty)
              .toList();
          if (mounted) {
            setState(() => _bannerImages = urls);
            _startBannerAutoPlay();
          }
        });
  }

  @override
  void dispose() {
    _bannerSub?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSendingOtp) return;

    final phone = _phoneController.text.trim();

    setState(() => _isSendingOtp = true);

    Log.i('BasicDetailsScreen', 'Sending WhatsApp OTP to: $phone');

    final result = await _otpService.sendOtp(phone: phone);

    if (!mounted) return;

    setState(() => _isSendingOtp = false);

    if (!result['success']) {
      Log.e('BasicDetailsScreen', 'Send OTP failed: ${result['message']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('OTP sent to your WhatsApp. Please check your phone.'),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    Log.i('BasicDetailsScreen', 'BasicDetailsScreen -> OTPVerificationScreen');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OTPVerificationScreen(
          signupType: widget.signupType,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: phone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ---- HERO BANNER ----
          SizedBox(
            height: size.height * 0.4,
            width: double.infinity,
            child: Stack(
              children: [
                // Banner image
                Positioned.fill(
                  child: _bannerImages.isEmpty
                      ? Image.asset(
                          'assets/images/signup_poster.png',
                          fit: BoxFit.cover,
                        )
                      : PageView.builder(
                          controller: _bannerController,
                          itemCount: _bannerImages.length,
                          onPageChanged: (i) {
                            setState(() => _currentBannerPage = i);
                          },
                          itemBuilder: (context, index) {
                            return CachedNetworkImage(
                              imageUrl: _bannerImages[index],
                              fit: BoxFit.cover,
                              memCacheWidth: 800,
                              fadeInDuration: const Duration(milliseconds: 200),
                              fadeOutDuration: const Duration(
                                milliseconds: 100,
                              ),
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFFF5722),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFF0A0A0D),
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white24,
                                    size: 48,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Gradient overlay at bottom for smooth transition
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 100,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                ),

                // Dot indicators
                if (_bannerImages.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_bannerImages.length, (i) {
                        final isActive = i == _currentBannerPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 24 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: isActive
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFF5722),
                                      Color(0xFFFF8A65),
                                    ],
                                  )
                                : null,
                            color: isActive
                                ? null
                                : Colors.white.withValues(alpha: 0.35),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFF5722,
                                      ).withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),

          // ---- FORM SECTION ----
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),

                    // Title with glow
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        final glowValue = _glowAnimation.value;
                        return ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              colors: const [
                                Color(0xFFFF5722),
                                Color(0xFF6A26E3),
                                Color(0xFFFF5722),
                              ],
                              stops: [
                                (glowValue - 0.2).clamp(0.0, 1.0),
                                glowValue,
                                (glowValue + 0.2).clamp(0.0, 1.0),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds);
                          },
                          child: Text(
                            widget.signupType == 'customer'
                                ? 'CUSTOMER DETAILS'
                                : 'PROFESSIONAL DETAILS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              shadows: [
                                Shadow(
                                  color: const Color(
                                    0xFFFF5722,
                                  ).withValues(alpha: 0.8 * glowValue),
                                  blurRadius: 20 * glowValue,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 6),
                    Text(
                      'Please provide your basic information to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Form Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A0D).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFF5722,
                            ).withValues(alpha: 0.08),
                            blurRadius: 40,
                            spreadRadius: -10,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildField(
                            TextFormField(
                              controller: _nameController,
                              focusNode: _nameFocusNode,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              decoration: _inputDecoration(
                                'Full Name',
                                Icons.person_outline_rounded,
                                _isNameFocused,
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Enter your name'
                                  : null,
                            ),
                            _isNameFocused,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            TextFormField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              decoration: _inputDecoration(
                                'Email Address',
                                Icons.email_outlined,
                                _isEmailFocused,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your email';
                                }
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(value)) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            _isEmailFocused,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            TextFormField(
                              controller: _phoneController,
                              focusNode: _phoneFocusNode,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              decoration: _inputDecoration(
                                'Phone Number',
                                Icons.phone_android_rounded,
                                _isPhoneFocused,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your phone number';
                                }
                                if (value.length < 10) {
                                  return 'Enter a valid phone number';
                                }
                                return null;
                              },
                            ),
                            _isPhoneFocused,
                          ),
                          const SizedBox(height: 28),
                          _buildActionButton(),
                          const SizedBox(height: 20),
                          _buildBackToLogin(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(Widget child, bool isFocused) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: const Color(0xFFFF5722).withValues(alpha: 0.12),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, bool isFocused) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: 16,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFFFF5722), size: 22),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF5722), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _buildActionButton() {
    return GestureDetector(
      onTap: _isSendingOtp ? null : _onNext,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: _isSendingOtp
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "Send OTP",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildBackToLogin() {
    return GestureDetector(
      onTap: () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Login',
              style: TextStyle(
                color: const Color(0xFFFF5722),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.4),
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
