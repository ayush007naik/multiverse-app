import 'package:flutter/material.dart';
import '../core/app_constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080B),
      body: Stack(
        children: [
          _buildAmbientGlow(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEffectiveDate(),
                        const SizedBox(height: 24),
                        _buildIntroSection(),
                        const SizedBox(height: 24),
                        _buildSection(
                          '1. Information We Collect',
                          'a) Personal Information\n\n'
                              'We may collect:\n\n'
                              '• Full Name\n'
                              '• Phone Number\n'
                              '• Email Address\n'
                              '• Delivery Address\n'
                              '• Profile Photo (optional)\n'
                              '• Payment Information (processed securely through third-party gateways)\n\n'
                              'b) Device & App Information\n\n'
                              'We may automatically collect:\n\n'
                              '• Device model\n'
                              '• Operating system\n'
                              '• App version\n'
                              '• IP address\n'
                              '• Crash logs\n'
                              '• Usage analytics\n\n'
                              'c) Location Information\n\n'
                              'To provide delivery tracking, nearby services, ETA calculations, and address detection, we may collect your real-time location data with your permission.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '2. How We Use Your Information',
                          'We use your information to:\n\n'
                              '• Process and deliver orders\n'
                              '• Enable real-time order tracking\n'
                              '• Improve user experience\n'
                              '• Manage wallet and payments\n'
                              '• Provide customer support\n'
                              '• Send order updates and notifications\n'
                              '• Prevent fraud and unauthorized access\n'
                              '• Improve app performance and security',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '3. Payments',
                          'Payments are securely processed using trusted third-party payment gateways such as:\n\n'
                              '• Razorpay\n'
                              '• UPI Providers\n'
                              '• Google Pay\n'
                              '• PhonePe\n'
                              '• Paytm\n\n'
                              'We do not store your card or banking details on our servers.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '4. Wallet System',
                          'If you use the Multiverse Wallet:\n\n'
                              '• Wallet balances are securely stored\n'
                              '• Transactions are recorded for security and accounting purposes\n'
                              '• Refunds and cashback may be credited to your wallet',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '5. Delivery & Tracking',
                          'For delivery-related services:\n\n'
                              '• Your address may be shared with delivery partners\n'
                              '• Real-time tracking may use GPS/location services\n'
                              '• Delivery partners may contact you regarding your order',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '6. Data Sharing',
                          'We do not sell your personal information.\n\n'
                              'We may share limited information with:\n\n'
                              '• Delivery partners\n'
                              '• Vendors/stores fulfilling your order\n'
                              '• Payment providers\n'
                              '• Legal authorities if required by law',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '7. Data Security',
                          'We implement industry-standard security measures to protect your data, including:\n\n'
                              '• Secure authentication\n'
                              '• Encrypted communication\n'
                              '• Access control systems\n'
                              '• Secure cloud storage\n\n'
                              'However, no digital platform can guarantee absolute security.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '8. Third-Party Services',
                          'Multiverse may use third-party services including:\n\n'
                              '• Firebase\n'
                              '• Google Maps Platform\n'
                              '• Razorpay\n'
                              '• Analytics providers\n\n'
                              'These services may collect data according to their own privacy policies.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '9. Your Rights',
                          'You may:\n\n'
                              '• Update your profile information\n'
                              '• Request account deletion\n'
                              '• Manage permissions (location, notifications, etc.)\n'
                              '• Contact support regarding your data',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '10. Children\'s Privacy',
                          'Multiverse is not intended for children under 13 years of age. We do not knowingly collect information from minors.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '11. Changes to This Policy',
                          'We may update this Privacy Policy from time to time. Updated versions will be posted within the app.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '12. Contact Us',
                          'If you have questions regarding this Privacy Policy, contact us:\n\n'
                              'Multiverse Support\n'
                              'Email: ${AppContactInfo.supportEmail}\n'
                              'Phone: +91 7018641456\n\n'
                              'By using Multiverse, you agree to this Privacy Policy and our Terms of Service.',
                        ),
                        const SizedBox(height: 40),
                        // Acceptance note
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6A3D), Color(0xFFFF8B5E)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your privacy and data security are our top priority.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Footer
                        Center(
                          child: Text(
                            'Last updated: May 2026',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
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
        ],
      ),
    );
  }

  Widget _buildAmbientGlow() {
    return Positioned(
      top: -100,
      right: -50,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFF6A3D).withValues(alpha: 0.12),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF15151A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'PRIVACY POLICY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffectiveDate() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6A3D).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF6A3D).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            color: Color(0xFFFF6A3D),
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            'Effective Date: May, 2026',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF15151A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: const Text(
        'Welcome to Multiverse. Your privacy is important to us. This Privacy Policy explains how Multiverse collects, uses, stores, and protects your information when you use our application and services.',
        style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF15151A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
