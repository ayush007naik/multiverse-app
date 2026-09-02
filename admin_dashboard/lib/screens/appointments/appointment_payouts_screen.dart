import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class AppointmentPayoutsScreen extends StatefulWidget {
  const AppointmentPayoutsScreen({super.key});

  @override
  State<AppointmentPayoutsScreen> createState() => _AppointmentPayoutsScreenState();
}

class _AppointmentPayoutsScreenState extends State<AppointmentPayoutsScreen> {
  final Map<String, String> _partnerNames = {};

  Future<void> _fetchPartnerName(String id) async {
    if (_partnerNames.containsKey(id) || id.isEmpty) return;
    try {
      String? name;
      final doc = await FirebaseFirestore.instance.collection('partners').doc(id).get();
      if (doc.exists) {
        name = _extractPartnerName(doc.data());
      }
      // Partners may be keyed by application id rather than the auth userId
      // the payout references, so fall back to a match on the stored userId.
      name ??= await _resolvePartnerNameByUserId(id);
      if (mounted && name != null && name.isNotEmpty) {
        final resolvedName = name;
        setState(() => _partnerNames[id] = resolvedName);
      }
    } catch (_) {}
  }

  String? _extractPartnerName(Map<String, dynamic>? d) {
    if (d == null) return null;
    final basic = (d['basic_info'] ?? d['basicInfo']) as Map? ?? {};
    final business = (d['business_details'] ?? d['businessDetails']) as Map? ?? {};
    final raw = d['name'] ?? basic['full_name'] ?? business['name'] ?? d['businessName'];
    final s = raw?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  Future<String?> _resolvePartnerNameByUserId(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('partners')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      for (final doc in snap.docs) {
        final name = _extractPartnerName(doc.data());
        if (name != null) return name;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Partner Payout Requests',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('payouts')
                    // Removing orderBy for now to avoid Index errors and find missing fields
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  // Filter manually in memory to handle legacy data without indexes
                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final type = data['recipientType']?.toString();
                    final hasPartnerId = data.containsKey('partnerId');
                    
                    // Show if it's explicitly 'appointment' OR if it has 'partnerId' (legacy)
                    return type == 'appointment' || (type == null && hasPartnerId);
                  }).toList();

                  // Sort in memory instead of Firestore to bypass index requirement
                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                    final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                    return bTime.compareTo(aTime);
                  });

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No payout requests found', style: TextStyle(color: Colors.white54)),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      try {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final recipientId = data['recipientId'] ?? data['partnerId'] ?? '';
                        _fetchPartnerName(recipientId);
                        
                        return _buildPayoutCard(docs[index].id, data);
                      } catch (e) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          color: Colors.red.withOpacity(0.1),
                          child: Text('Error loading item: $e', style: const TextStyle(color: Colors.red, fontSize: 10)),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  DateTime? _tsToDate(dynamic ts) {
    if (ts == null) return null;
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return null;
  }

  Widget _buildPayoutCard(String docId, Map<String, dynamic> data) {
    final String recipientId = data['recipientId'] ?? data['partnerId'] ?? '';
    final String partnerName = data['recipientName'] ?? data['partnerName'] ?? _partnerNames[recipientId] ?? 'Unknown Partner';
    final double amount = _toDouble(data['amount']);
    final String status = data['status'] ?? 'pending';
    final DateTime requestedAt = _tsToDate(data['createdAt'] ?? data['requestedAt']) ?? DateTime.now();
    
    Color statusColor = Colors.orange;
    if (status == 'paid') statusColor = Colors.green;
    if (status == 'rejected') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet, color: AppTheme.accentOrange),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partnerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Partner ID: $recipientId', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 8),
                if (data['bankDetails'] != null)
                  Text(
                    'BANK: ${data['bankDetails']['accountHolder'] ?? data['bankDetails']['accountName'] ?? ''} | ${data['bankDetails']['accountNumber'] ?? ''} | ${data['bankDetails']['ifsc'] ?? ''}',
                    style: const TextStyle(color: AppTheme.accentOrange, fontSize: 12),
                  ),
                if (data['upiDetails'] != null)
                  Text(
                    'UPI: ${data['upiDetails']['name'] ?? ''} | ${data['upiDetails']['upiId'] ?? ''}',
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
              Text(DateFormat('MMM dd, yyyy').format(requestedAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(width: 24),
          if (status == 'pending')
            Row(
              children: [
                _buildActionButton(Icons.check, Colors.green, () => _updateStatus(docId, 'paid')),
                const SizedBox(width: 8),
                _buildActionButton(Icons.close, Colors.red, () => _updateStatus(docId, 'rejected')),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Future<void> _updateStatus(String docId, String status) async {
    try {
      await FirebaseFirestore.instance.collection('payouts').doc(docId).update({
        'status': status,
        'processedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payout $status successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
