import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/appointment_provider.dart';
import '../../widgets/glass_card.dart';
import '../../services/pdf_service.dart';

class AppointmentApprovalsScreen extends StatefulWidget {
  const AppointmentApprovalsScreen({super.key});

  @override
  State<AppointmentApprovalsScreen> createState() => _AppointmentApprovalsScreenState();
}

class _AppointmentApprovalsScreenState extends State<AppointmentApprovalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppointmentProvider>();

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
                      'Partner Approvals',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage signup requests from service partners.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicator: BoxDecoration(
                      color: AppTheme.primaryPurple,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'PENDING'),
                      Tab(text: 'APPROVED'),
                      Tab(text: 'REJECTED'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: provider.error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              provider.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(context, provider.pendingApplications, provider, 'pending'),
                        _buildList(context, provider.approvedApplications, provider, 'approved'),
                        _buildList(context, provider.rejectedApplications, provider, 'rejected'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Map<String, dynamic>> apps, AppointmentProvider provider, String status) {
    if (apps.isEmpty) return _buildEmptyState(status);
    return _buildApplicationsList(context, apps, provider);
  }

  Widget _buildEmptyState(String status) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            status == 'pending' ? Icons.check_circle_outline : Icons.history,
            size: 80,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            'No $status applications',
            style: const TextStyle(color: Colors.white54, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList(BuildContext context, List<Map<String, dynamic>> apps, AppointmentProvider provider) {
    return ListView.builder(
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final basic = (app['basic_info'] ?? app['basicInfo']) as Map? ?? {};
        final business = (app['business_details'] ?? app['businessDetails']) as Map? ?? {};
        final professional = app['professional_details'] as Map? ?? {};
        final images = app['images'] as Map? ?? {};
        final docs = images['docs'] as Map? ?? {};
        final bank = app['bank_details'] as Map? ?? {};

        return GlassCard(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            iconColor: AppTheme.primaryPurple,
            collapsedIconColor: Colors.white54,
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  backgroundImage: images['profile'] != null && images['profile'] != ''
                      ? NetworkImage(images['profile'])
                      : null,
                  child: images['profile'] == null || images['profile'] == ''
                      ? Text(
                          (basic['full_name'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        basic['full_name'] ?? 'Unknown Partner',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        app['category'] ?? 'General',
                        style: const TextStyle(color: AppTheme.primaryPurple, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(app['status'] ?? 'pending'),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${business['name'] ?? 'No Business Name'} • ${business['city'] ?? 'No City'}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (app['status'] == 'approved') ...[
                       Align(
                        alignment: Alignment.topRight,
                        child: TextButton.icon(
                          onPressed: () => PdfService.generatePartnerAgreement(app),
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('GENERATE AGREEMENT'),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const Divider(color: Colors.white10),
                    
                    // --- SECTION: BASIC INFO ---
                    _buildSectionHeader('PERSONAL INFORMATION'),
                    Row(
                      children: [
                        Expanded(child: _buildDetailRow('Email', basic['email'] ?? 'N/A')),
                        Expanded(child: _buildDetailRow('Mobile', basic['mobile'] ?? 'N/A')),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildDetailRow('DOB', basic['dob'] ?? 'N/A')),
                        Expanded(child: _buildDetailRow('Gender', basic['gender'] ?? 'N/A')),
                      ],
                    ),

                    const SizedBox(height: 20),
                    // --- SECTION: PROFESSIONAL DETAILS ---
                    _buildSectionHeader('PROFESSIONAL DETAILS'),
                    if (app['category'] == 'Doctor' || app['category'] == 'Dentist') ...[
                      Row(
                        children: [
                          Expanded(child: _buildDetailRow('Qualification', professional['qualification'] ?? 'N/A')),
                          Expanded(child: _buildDetailRow('Experience', '${professional['experience'] ?? 0} Years')),
                        ],
                      ),
                      _buildDetailRow('Reg No.', professional['registration_no'] ?? 'N/A'),
                      _buildDetailRow('Specialization', professional['specialization'] ?? 'N/A'),
                    ],
                    if (app['category'] == 'Salon') ...[
                      _buildDetailRow('Salon Type', professional['salon_type'] ?? 'N/A'),
                      _buildDetailRow('Staff Count', professional['staff_count']?.toString() ?? '1'),
                    ],
                    if (app['category'] == 'Diagnostic Lab') ...[
                      _buildDetailRow('Lab Reg No.', professional['registration_no'] ?? 'N/A'),
                      _buildDetailRow('NABL Accredited', professional['lab_nabl'] == true ? 'YES' : 'NO'),
                      _buildDetailRow('Home Collection', professional['home_sample'] == true ? 'YES' : 'NO'),
                    ],

                    const SizedBox(height: 20),
                    // --- SECTION: BUSINESS DETAILS ---
                    _buildSectionHeader('BUSINESS LOCATION'),
                    _buildDetailRow('Entity Name', business['name'] ?? 'N/A'),
                    _buildDetailRow('Address', business['address'] ?? 'N/A'),
                    Row(
                      children: [
                        Expanded(child: _buildDetailRow('City', business['city'] ?? 'N/A')),
                        Expanded(child: _buildDetailRow('Pincode', business['pincode'] ?? 'N/A')),
                      ],
                    ),
                    if (business['location'] != null)
                      _buildDetailRow('GPS', '${business['location']['lat']}, ${business['location']['lng']}'),

                    const SizedBox(height: 20),
                    // --- SECTION: DOCUMENTS & PHOTOS ---
                    _buildSectionHeader('DOCUMENTS & MEDIA'),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (docs['id_proof'] != null) _buildDocPreview('ID Proof', docs['id_proof']),
                        if (docs['license'] != null) _buildDocPreview('License', docs['license']),
                        if (docs['address_proof'] != null) _buildDocPreview('Address Proof', docs['address_proof']),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (images['business'] != null && (images['business'] as List).isNotEmpty) ...[
                      const Text('Business Photos:', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: (images['business'] as List).length,
                          itemBuilder: (context, i) => _buildThumbnail(images['business'][i]),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    // --- SECTION: BANK DETAILS ---
                    _buildSectionHeader('BANK ACCOUNT'),
                    Row(
                      children: [
                        Expanded(child: _buildDetailRow('Bank', bank['bank_name'] ?? 'N/A')),
                        Expanded(child: _buildDetailRow('IFSC', bank['ifsc'] ?? 'N/A')),
                      ],
                    ),
                    _buildDetailRow('A/C Holder', bank['holder_name'] ?? 'N/A'),
                    _buildDetailRow('A/C Number', bank['account_no'] ?? 'N/A'),

                    const SizedBox(height: 20),
                    // --- SECTION: SIGNATURE & AGREEMENT ---
                    if (app['signature'] != null && app['signature'] != '') ...[
                      _buildSectionHeader('SERVICE AGREEMENT'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 100,
                            width: 180,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: app['signature'],
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Digitally signed and accepted by the partner.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _showAgreementDialog(context),
                                  icon: const Icon(Icons.description, size: 16),
                                  label: const Text('VIEW TERMS'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.2),
                                    foregroundColor: AppTheme.primaryPurple,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 32),
                    // --- ACTION BUTTONS ---
                    if (app['status'] == 'pending')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _showRejectDialog(context, provider, app['id']),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          child: const Text('REJECT APPLICATION'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () => _showApproveDialog(context, provider, app['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          child: const Text('APPROVE PARTNER'),
                        ),
                      ],
                    ),
                    if (app['status'] == 'approved') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _resendWelcomeEmail(
                            'appointment',
                            app['id'],
                            recipient: basic['email'] != null && basic['email'] != ''
                                ? basic['email'].toString()
                                : null,
                          ),
                          icon: const Icon(Icons.mail_outline, size: 16),
                          label: const Text('Resend Welcome Email'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryPurple,
                            side: const BorderSide(color: AppTheme.primaryPurple),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primaryPurple,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDocPreview(String label, String url) {
    return InkWell(
      onTap: () => _launchURL(url),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description, color: AppTheme.primaryPurple, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String url) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _launchURL(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: url,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.white10),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _resendWelcomeEmail(String platform, String id, {String? recipient}) async {
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('resendApprovalEmail')
          .call({'platform': platform, 'id': id});
      final data = result.data as Map<String, dynamic>;
      if (!mounted) return;
      final sent = data['sent'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sent
            ? 'Welcome email sent to ${data['email'] ?? recipient ?? 'partner'}'
            : 'Email not sent: ${data['reason'] ?? 'unknown reason'}'),
        backgroundColor: sent ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to resend email: $e'),
        backgroundColor: const Color(0xFFF44336),
      ));
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(BuildContext context, AppointmentProvider provider, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Approve Partner'),
        content: const Text('Are you sure you want to approve this application? The partner will be notified and granted access to their dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              provider.updateApplicationStatus(id, 'approved');
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('APPROVE'),
          ),
        ],
      ),
    );
  }

  void _showAgreementDialog(BuildContext context) {
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
        title: const Text('Service Provider Agreement'),
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

  void _showRejectDialog(BuildContext context, AppointmentProvider provider, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Reject Application'),
        content: const Text('Are you sure you want to reject this application? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              provider.updateApplicationStatus(id, 'rejected');
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('REJECT'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
