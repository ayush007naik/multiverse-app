import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:animate_do/animate_do.dart';
import '../../providers/auth_provider.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onShowSignup;

  const LoginScreen({super.key, required this.onShowSignup});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Colors based on the design
  static const Color _bgBlack = Color(0xFF000000);
  static const Color _secondaryPink = Color(0xFFFF1744);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final error = await authProvider.login(email, password);

    if (error != null && mounted) {
      _showSnackBar(error);
      setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _secondaryPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: _bgBlack,
      body: SingleChildScrollView(
        child: Container(
          width: size.width,
          constraints: BoxConstraints(
            minHeight: size.height,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? size.width * 0.08 : 20,
            vertical: isDesktop ? 40 : 40,
          ),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _buildLeftContent()),
                    const SizedBox(width: 60),
                    _buildLoginCard(),
                  ],
                )
              : Column(
                  children: [
                    _buildLeftContent(),
                    const SizedBox(height: 60),
                    _buildLoginCard(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLeftContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInDown(
          duration: const Duration(milliseconds: 500),
          child: Row(
            children: [
              Image.asset('assets/images/logo.png', height: 40),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MULTIVERSE',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'THEATRE PORTAL',
                    style: GoogleFonts.rajdhani(
                      color: _secondaryPink,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 60),
        FadeInLeft(
          delay: const Duration(milliseconds: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WELCOME TO THE',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'FUTURE OF ',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF5F00), Color(0xFFFFCC00)],
                    ).createShader(bounds),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'THEA',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.theater_comedy_outlined, color: Colors.white, size: 40),
                        ),
                        Text(
                          'TRE',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FadeInLeft(
          delay: const Duration(milliseconds: 300),
          child: SizedBox(
            width: 500,
            child: Text(
              'Manage your theatre, staff and grow your business with powerful tools designed for theatre operators.',
              style: GoogleFonts.rajdhani(
                color: const Color(0xFF9E9E9E),
                fontSize: 18,
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
        FadeInUp(
          delay: const Duration(milliseconds: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PORTAL FEATURES',
                style: GoogleFonts.orbitron(
                  color: const Color(0xFFFF1744),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFeatureIcon(Icons.theater_comedy_outlined, 'SHOW\nMANAGEMENT', const Color(0xFFFF5F00)),
                    _buildFeatureIcon(Icons.people_alt_outlined, 'STAFF\nMANAGEMENT', const Color(0xFFFF1744)),
                    _buildFeatureIcon(Icons.event_seat_outlined, 'SEAT & SHOW\nSCHEDULING', const Color(0xFFFF5F00)),
                    _buildFeatureIcon(Icons.confirmation_num_outlined, 'BOOKINGS &\nTICKETS', Colors.cyan),
                    _buildFeatureIcon(Icons.notifications_active_outlined, 'NOTIFICATIONS', const Color(0xFFFF1744)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        FadeInUp(
          delay: const Duration(milliseconds: 500),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF08080E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFFFF5F00), Color(0xFFFF1744)]),
                  ),
                  child: const Icon(Icons.movie_creation_outlined, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deliver Unforgettable Experiences. Every Show.',
                        style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All-in-one platform to simplify your theatre operations.',
                        style: GoogleFonts.rajdhani(color: const Color(0xFF9E9E9E), fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildMiniBadge(Icons.check_circle, 'Secure', Colors.purpleAccent),
                          const SizedBox(width: 16),
                          _buildMiniBadge(Icons.bolt, 'Reliable', Colors.purpleAccent),
                          const SizedBox(width: 16),
                          _buildMiniBadge(Icons.auto_awesome, 'Intelligent', Colors.purpleAccent),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label, Color color) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF08080E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Center(child: Icon(icon, color: color, size: 28)),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 3, width: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.rajdhani(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildLoginCard() {
    return FadeInRight(
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: const Color(0xFF08080E),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5F00).withValues(alpha: 0.05),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', height: 80),
              const SizedBox(height: 12),
              Text(
                'MULTIVERSE',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome Back ',
                    style: GoogleFonts.rajdhani(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('👋', style: TextStyle(fontSize: 24)),
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.rajdhani(color: const Color(0xFF9E9E9E), fontSize: 16),
                  children: const [
                    TextSpan(text: 'Login to access your '),
                    TextSpan(
                      text: 'theatre dashboard',
                      style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              _buildTextField(
                controller: _emailController,
                hint: 'Enter your email',
                icon: Icons.mail_outline,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _passwordController,
                hint: 'Enter your password',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Forgot Password?',
                    style: GoogleFonts.rajdhani(color: const Color(0xFFFF1744), fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildLoginButton(),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: GoogleFonts.rajdhani(color: const Color(0xFF9E9E9E), fontSize: 15),
                  ),
                  GestureDetector(
                    onTap: widget.onShowSignup,
                    child: Text(
                      'Become a partner',
                      style: GoogleFonts.rajdhani(
                        color: const Color(0xFFFF1744),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Already have a Vendor or Appointment account? Sign up with the same Email & Password — your Theatre profile will be added to the same account. One ID & Password works across Vendor, Theatre and Appointment apps.',
                        style: GoogleFonts.rajdhani(
                          color: const Color(0xFFFFD9A0),
                          fontSize: 13,
                          height: 1.4,
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _obscurePassword,
      style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.rajdhani(color: const Color(0xFF9E9E9E)),
        prefixIcon: Icon(icon, color: const Color(0xFF9E9E9E), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF9E9E9E),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF0D0D14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFFF5F00), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Field required';
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5F00), Color(0xFFFF1744)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF1744).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Login',
                    style: GoogleFonts.rajdhani(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
      ),
    );
  }
}