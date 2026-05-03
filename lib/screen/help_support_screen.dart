import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static final Uri _whatsAppUri = Uri.parse('https://wa.me/918123281987');
  static final Uri _callUri = Uri.parse('tel:+918123281987');
  static final Uri _emailUri = Uri(
    scheme: 'mailto',
    path: 'ayu007n@gmail.com',
    query: 'subject=Multiverse Support',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text(
          'Help & Support',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Reach the support team directly',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _supportTile(
            context,
            icon: Icons.chat_rounded,
            color: 0xFF25D366,
            title: 'WhatsApp',
            subtitle: 'Fastest way to get order help',
            onTap: () => _launch(context, _whatsAppUri),
          ),
          _supportTile(
            context,
            icon: Icons.call_rounded,
            color: 0xFF4CAF50,
            title: 'Call',
            subtitle: '+91 81232 81987',
            onTap: () => _launch(context, _callUri),
          ),
          _supportTile(
            context,
            icon: Icons.email_rounded,
            color: 0xFF2196F3,
            title: 'Email',
            subtitle: 'ayu007n@gmail.com',
            onTap: () => _launch(context, _emailUri),
          ),
        ],
      ),
    );
  }

  Widget _supportTile(
    BuildContext context, {
    required IconData icon,
    required int color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272727)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Color(color).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Color(color)),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF888888)),
        ),
        trailing: const Icon(
          Icons.open_in_new_rounded,
          color: Color(0xFF666666),
        ),
      ),
    );
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (success || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open support channel'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}
