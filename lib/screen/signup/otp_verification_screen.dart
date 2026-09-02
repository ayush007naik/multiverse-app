import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:db_compat/db_compat.dart';
import '../../core/logging_service.dart';
import '../../services/otp_auth_service.dart';
import '../../services/auth_flow_service.dart';
import '../../services/security_tracking_service.dart';
import '../../widgets/premium_ui_widgets.dart';
import 'role_selection_screen.dart';
import 'location_details_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String signupType;
  final String name;
  final String email;
  final String phone;

  const OTPVerificationScreen({
    super.key,
    required this.signupType,
    required this.name,
    required this.email,
    required this.phone,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  final OtpAuthService _otpService = OtpAuthService();
  final AuthFlowService _authFlowService = AuthFlowService();

  final FocusNode _otpFocusNode = FocusNode();
  bool _isOtpFocused = false;

  bool _isLoading = false;
  bool _isSendingOtp = false;
  String _statusMessage = 'Enter the OTP sent to your WhatsApp';

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _otpFocusNode.addListener(
      () => setState(() => _isOtpFocused = _otpFocusNode.hasFocus),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
      _statusMessage = 'Sending OTP to +91 ${widget.phone}';
    });

    final result = await _otpService.sendOtp(phone: widget.phone);

    if (!mounted) return;

    setState(() {
      _isSendingOtp = false;
      _statusMessage = result['success']
          ? 'OTP resent to +91 ${widget.phone}'
          : 'Failed to send OTP';
    });

    if (!result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Verifying...';
    });

    try {
      final result = await _otpService.verifyOtp(
        phone: widget.phone,
        enteredOtp: _otpController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        await FirebaseAuth.instance.signInWithCustomToken(
          result['customToken'],
        );
        final uid = result['uid'] as String;
        if (!mounted) return;
        await _onVerificationSuccess(uid);
        SecurityTrackingService.recordLogin(uid: uid, phone: widget.phone, success: true);
        SecurityTrackingService.recordDevice(uid: uid);
        SecurityTrackingService.recordActivity(uid: uid, activity: 'Logged in');
      } else {
        SecurityTrackingService.recordLogin(
          uid: FirebaseAuth.instance.currentUser?.uid ?? '',
          phone: widget.phone,
          success: false,
        );
        setState(() {
          _isLoading = false;
          _statusMessage = result['message'];
        });
      }
    } catch (e) {
      Log.e('OTPVerificationScreen', 'OTP Error: $e');
      SecurityTrackingService.recordLogin(
        uid: FirebaseAuth.instance.currentUser?.uid ?? '',
        phone: widget.phone,
        success: false,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Verification failed';
      });
    }
  }

  Future<void> _onVerificationSuccess(String uid) async {
    await _otpService.saveUserSession(uid);
    final fullPhone = widget.phone.startsWith('+')
        ? widget.phone
        : '+91${widget.phone}';

    await _authFlowService.ensureUserProfile(
      uid: uid,
      name: widget.name,
      email: widget.email,
      phoneNumber: fullPhone,
      defaultRoles: [widget.signupType],
    );

    // Save FCM token for push notifications
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
          'notificationEnabled': true,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, const SetOptions(merge: true));
      }
    } catch (_) {}

    if (!mounted) return;
    if (widget.signupType == 'customer') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LocationDetailsScreen(
            uid: uid,
            name: widget.name,
            email: widget.email,
            phone: widget.phone,
          ),
        ),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => RoleSelectionScreen(
            uid: uid,
            name: widget.name,
            email: widget.email,
            phone: widget.phone,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
      ),
      body: SafeArea(
        child: FadeSlideAnimation(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildTitle(),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                GlassCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(20),
                  opacity: 0.05,
                  shadows: [
                    BoxShadow(
                      color: const Color(0xFFFF5722).withValues(alpha: 0.1),
                      blurRadius: 40,
                      spreadRadius: -10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  child: Column(
                    children: [
                      _buildAnimatedField(
                        TextField(
                          controller: _otpController,
                          focusNode: _otpFocusNode,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 16,
                          ),
                          textAlign: TextAlign.center,
                          decoration: _inputDecoration(
                            "000000",
                            Icons.lock_outline_rounded,
                            _isOtpFocused,
                          ),
                          onChanged: (val) {
                            if (val.length == 6) _verifyOtp();
                          },
                        ),
                        _isOtpFocused,
                      ),
                      const SizedBox(height: 24),
                      _buildActionButton(),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isSendingOtp ? null : _sendOtp,
                        child: Text(
                          'Resend Code',
                          style: TextStyle(
                            color: _isSendingOtp
                                ? Colors.grey
                                : const Color(0xFFFF5722),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
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
            'VERIFY PHONE',
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
    );
  }

  Widget _buildAnimatedField(Widget child, bool isFocused) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: const Color(0xFFFF5722).withValues(alpha: 0.15),
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
        letterSpacing: 0,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFFFF5722), size: 22),
      counterText: '',
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFF5722), width: 2),
      ),
    );
  }

  Widget _buildActionButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _verifyOtp,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "Verify & Continue",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
      ),
    );
  }
}
