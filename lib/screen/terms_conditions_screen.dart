import 'package:flutter/material.dart';
import '../core/app_constants.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
                        _buildLastUpdated(),
                        const SizedBox(height: 24),
                        _buildIntroSection(),
                        const SizedBox(height: 24),
                        _buildSection(
                          '1. About Multiverse',
                          'Multiverse is a multi-service digital platform connecting users with local businesses, products, services, and cross-city delivery solutions across Mandi District, including Mandi, Nerchowk, Sundernagar, and surrounding areas.\n\n'
                              'The platform may include:\n\n'
                              '• Grocery delivery\n'
                              '• Pharmacy services\n'
                              '• Electronics\n'
                              '• Fashion & beauty\n'
                              '• Furniture\n'
                              '• Property listings\n'
                              '• Movie ticket bookings\n'
                              '• Local business services\n'
                              '• Cross-city delivery\n'
                              '• Other digital marketplace services',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '2. Eligibility',
                          'By using Multiverse, you confirm that:\n\n'
                              '• You are legally capable of entering into binding agreements\n'
                              '• Information provided by you is accurate and updated\n'
                              '• You will use the platform only for lawful purposes\n\n'
                              'Users under 18 years must use the platform under parental or guardian supervision.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '3. User Accounts',
                          'Certain features require account registration.\n\n'
                              'You are responsible for:\n\n'
                              '• Maintaining confidentiality of your account\n'
                              '• All activities under your account\n'
                              '• Securing your login credentials\n\n'
                              'Multiverse reserves the right to suspend or terminate accounts involved in suspicious, fraudulent, abusive, or unlawful activities.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '4. Orders & Bookings',
                          '• All orders and bookings are subject to availability and confirmation\n'
                              '• Estimated delivery or service times are approximate and may vary\n'
                              '• Cross-city deliveries may depend on distance, traffic, weather, or partner availability\n'
                              '• Users must provide accurate addresses and contact information\n\n'
                              'Multiverse reserves the right to cancel or refuse orders in exceptional circumstances.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '5. Payments',
                          '• Payments are securely processed through authorized third-party payment gateways\n'
                              '• By making payments, users authorize Multiverse to process transactions on their behalf\n'
                              '• Prices, delivery charges, taxes, and convenience fees may change without prior notice\n'
                              '• Failed transactions caused by banks or payment providers are outside Multiverse\'s direct control',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '6. Refunds & Cancellations',
                          'Refund eligibility depends on:\n\n'
                              '• Order status\n'
                              '• Cancellation timing\n'
                              '• Merchant or service provider policies\n\n'
                              'Refunds, where applicable, may take several business days to reflect depending on banking partners and payment gateways.\n\n'
                              'Multiverse reserves the right to deny refund requests involving misuse, repeated cancellations, or suspicious activity.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '7. Delivery Policy',
                          '• Delivery timelines are estimated and not guaranteed\n'
                              '• Same-day delivery availability may vary based on city, product category, weather, and operational conditions\n'
                              '• Users must ensure availability at the delivery location\n\n'
                              'In cases of failed delivery due to incorrect address, unreachable customer, or refusal to accept the order, additional charges may apply.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '8. Merchant & Third-Party Services',
                          'Multiverse acts as a platform connecting users with independent merchants, stores, businesses, and service providers.\n\n'
                              'We are not directly responsible for:\n\n'
                              '• Product manufacturing defects\n'
                              '• Merchant delays\n'
                              '• Service quality issues\n'
                              '• Third-party operational failures\n\n'
                              'However, we aim to provide reasonable support in resolving disputes.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '9. Offers, Rewards & Promotions',
                          'Multiverse may offer:\n\n'
                              '• Cashback\n'
                              '• Promo codes\n'
                              '• Referral rewards\n'
                              '• Discounts\n'
                              '• Launch offers\n\n'
                              'All promotional offers:\n\n'
                              '• Are time-limited\n'
                              '• May contain category-specific conditions\n'
                              '• Cannot be exchanged for cash unless stated otherwise\n\n'
                              'We reserve the right to modify or discontinue promotional programs at any time.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '10. Prohibited Activities',
                          'Users agree not to:\n\n'
                              '• Use the platform fraudulently\n'
                              '• Abuse offers or payment systems\n'
                              '• Upload false, harmful, or misleading information\n'
                              '• Interfere with platform security or operations\n'
                              '• Attempt unauthorized access to accounts or systems\n\n'
                              'Violation may result in immediate suspension and possible legal action.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '11. Intellectual Property',
                          'All platform content including:\n\n'
                              '• Logos\n'
                              '• Branding\n'
                              '• Graphics\n'
                              '• App designs\n'
                              '• Text\n'
                              '• Software\n'
                              '• UI/UX elements\n\n'
                              'are the intellectual property of Multiverse and protected under applicable copyright and trademark laws.\n\n'
                              'Unauthorized copying or redistribution is prohibited.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '12. Privacy',
                          'Your use of Multiverse is also governed by our Privacy Policy regarding data collection, usage, and security practices.\n\n'
                              'By using the platform, you consent to our data handling practices.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '13. Limitation of Liability',
                          'Multiverse shall not be liable for:\n\n'
                              '• Indirect or incidental damages\n'
                              '• Delivery delays\n'
                              '• Third-party service interruptions\n'
                              '• Technical downtime\n'
                              '• Data loss caused by external systems\n'
                              '• Force majeure events beyond reasonable control\n\n'
                              'Users access the platform at their own discretion and risk.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '14. Platform Modifications',
                          'We reserve the right to:\n\n'
                              '• Modify app features\n'
                              '• Add or remove services\n'
                              '• Update pricing structures\n'
                              '• Revise these Terms at any time\n\n'
                              'Continued use of the platform after updates constitutes acceptance of revised Terms.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '15. Termination',
                          'Multiverse may suspend or terminate access without prior notice if:\n\n'
                              '• Terms are violated\n'
                              '• Fraudulent activity is detected\n'
                              '• Required by law or regulatory authorities',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '16. Governing Law',
                          'These Terms shall be governed by and interpreted under the laws of India.\n\n'
                              'Any disputes arising from the use of Multiverse shall fall under the jurisdiction of competent courts in Himachal Pradesh, India.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '17. Contact Information',
                          'For support, legal concerns, partnerships, or business inquiries:\n\n'
                              'Multiverse Support Team\n'
                              'Mandi District, Himachal Pradesh, India\n'
                              'Email: ${AppContactInfo.supportEmail}',
                        ),
                        const SizedBox(height: 40),
                        // Acceptance note
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFF6A3D,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFFFF6A3D,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                color: Color(0xFFFF6A3D),
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'By using Multiverse, you acknowledge that you have read and understood these Terms and Conditions.',
                                  style: TextStyle(
                                    color: Color(0xFFFF6A3D),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
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
          color: const Color(0xFFFF6A3D).withValues(alpha: 0.08),
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
          const Expanded(
            child: Text(
              'Terms & Conditions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            color: Color(0xFFFF6A3D),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Last Updated: May 2026',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        'Welcome to Multiverse ("we," "our," or "us"). These Terms & Conditions govern your access to and use of the Multiverse mobile application, website, and related services. By accessing or using Multiverse, you agree to comply with and be bound by these Terms.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            content,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
