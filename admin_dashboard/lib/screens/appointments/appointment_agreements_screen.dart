import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:db_compat/db_compat.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/appointment_provider.dart';
import '../../widgets/glass_card.dart';
import '../../services/pdf_service.dart';

class AppointmentAgreementsScreen extends StatefulWidget {
  const AppointmentAgreementsScreen({super.key});

  @override
  State<AppointmentAgreementsScreen> createState() => _AppointmentAgreementsScreenState();
}

class _AppointmentAgreementsScreenState extends State<AppointmentAgreementsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentProvider>();
    final allAgreements = provider.agreements;
    
    final filteredAgreements = allAgreements.where((app) {
      final basic = app['basic_info'] as Map? ?? {};
      final business = app['business_details'] as Map? ?? {};
      final name = (basic['full_name'] ?? '').toString().toLowerCase();
      final bizName = (business['name'] ?? '').toString().toLowerCase();
      final category = (app['category'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || bizName.contains(query) || category.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appointment Agreements',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Digitally signed contracts for approved service partners.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                _buildSearchField(),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: filteredAgreements.isEmpty
                  ? _buildEmptyState()
                  : _buildAgreementsList(filteredAgreements),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      width: 300,
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search partners...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryPurple),
          fillColor: AppTheme.darkSurface,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_edu, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No agreements yet' : 'No matching results',
            style: const TextStyle(color: Colors.white54, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementsList(List<Map<String, dynamic>> agreements) {
    return ListView.builder(
      itemCount: agreements.length,
      itemBuilder: (context, index) {
        final app = agreements[index];
        final basic = app['basic_info'] as Map? ?? {};
        final business = app['business_details'] as Map? ?? {};
        final approvedAt = app['approved_at'] as Timestamp?;
        
        String dateStr = 'N/A';
        if (approvedAt != null) {
          final date = approvedAt.toDate();
          dateStr = '${date.day}/${date.month}/${date.year}';
        }

        return GlassCard(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            iconColor: AppTheme.primaryPurple,
            collapsedIconColor: Colors.white54,
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  child: Text(
                    (basic['full_name'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        basic['full_name'] ?? 'Unknown Partner',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        app['category'] ?? 'General',
                        style: const TextStyle(color: AppTheme.primaryPurple, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('APPROVED ON', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    Text(dateStr, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetail('Business Name', business['name'] ?? 'N/A'),
                              _buildDetail('Email Address', basic['email'] ?? 'N/A'),
                              _buildDetail('Contact No.', basic['mobile'] ?? 'N/A'),
                              _buildDetail('Partner ID', app['id'] ?? 'N/A'),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DIGITAL SIGNATURE', style: TextStyle(color: AppTheme.primaryPurple, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                height: 120,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: app['signature'] != null && app['signature'] != ''
                                    ? CachedNetworkImage(
                                        imageUrl: app['signature'],
                                        fit: BoxFit.contain,
                                      )
                                    : const Center(child: Text('No Signature Found', style: TextStyle(color: Colors.black26))),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _showTermsDialog(context),
                                    icon: const Icon(Icons.description, size: 16),
                                    label: const Text('VIEW SIGNED TERMS'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.2),
                                      foregroundColor: AppTheme.primaryPurple,
                                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton.icon(
                                    onPressed: () => PdfService.generatePartnerAgreement(app),
                                    icon: const Icon(Icons.download, size: 16),
                                    label: const Text('DOWNLOAD PDF'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    final points = [
      "I confirm that all information provided during registration is true, accurate, and up to date.",
      "I possess all required licenses, registrations, certifications, and permissions to provide my services.",
      "I am solely responsible for the quality, safety, and legality of the services I provide.",
      "I agree to keep my profile, pricing, availability, and contact details updated.",
      "I understand that customer reviews and ratings may be displayed publicly.",
      "I agree not to post false, misleading, or fraudulent information.",
      "I understand that the platform may suspend or terminate my account if I violate these terms or provide false information.",
      "I authorize the platform to verify my identity and submitted documents when necessary.",
      "I agree to comply with all applicable laws, regulations, and professional standards.",
      "I understand that the platform acts only as a marketplace connecting customers and service providers and is not responsible for disputes, damages, or losses arising from services provided.",
      "I agree to the platform’s Privacy Policy and Terms of Service.",
      "I consent to receive notifications via SMS, email, WhatsApp, or phone regarding my account, bookings, and platform updates."
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Signed Service Agreement'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: points.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${e.key + 1}. ", style: const TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold, fontSize: 13)),
                    Expanded(child: Text(e.value, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
                  ],
                ),
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
        ],
      ),
    );
  }
}
