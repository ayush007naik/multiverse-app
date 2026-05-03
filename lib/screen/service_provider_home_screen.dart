// lib/screens/service_provider_home_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class ServiceProviderHomeScreen extends StatefulWidget {
  const ServiceProviderHomeScreen({super.key});

  @override
  State<ServiceProviderHomeScreen> createState() => _ServiceProviderHomeScreenState();
}

class _ServiceProviderHomeScreenState extends State<ServiceProviderHomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isAvailable = true;
  Map<String, dynamic>? _providerData;

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (mounted) {
      setState(() {
        _providerData = doc.data();
        _isAvailable = doc.data()?['isAvailable'] ?? true;
      });
    }
  }

  Future<void> _toggleAvailability() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    HapticFeedback.lightImpact();
    setState(() => _isAvailable = !_isAvailable);
    await _firestore.collection('users').doc(uid).update({'isAvailable': _isAvailable});
    await _firestore.collection('service_providers').doc(uid).update({'isAvailable': _isAvailable});
  }

  Future<void> _acceptBid(String requestId, String bidId) async {
    await _firestore
        .collection('service_requests')
        .doc(requestId)
        .update({'status': 'accepted', 'acceptedBidId': bidId});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request accepted!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    final serviceType = _providerData?['serviceType'] ?? 'Service Provider';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _providerData?['name'] ?? 'Provider',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              serviceType,
              style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 13),
            ),
          ],
        ),
        actions: [
          // Availability Toggle
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _toggleAvailability,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _isAvailable
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isAvailable ? Colors.green : Colors.grey,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: _isAvailable ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isAvailable ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: _isAvailable ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('service_requests')
            .where('serviceType', isEqualTo: serviceType)
            .where('status', isEqualTo: 'open')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D4F)));
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_off_outlined, color: Colors.grey[700], size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'No new requests',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'New service requests will appear here',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final data = requests[index].data() as Map<String, dynamic>;
              final requestId = requests[index].id;
              return _buildRequestCard(data, requestId);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> data, String requestId) {
    final uid = _auth.currentUser?.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D4F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.handyman, color: Color(0xFFFF4D4F)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['serviceType'] ?? '',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      data['customerName'] ?? 'Customer',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹${data['customerBudget'] ?? '0'} budget',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 12),

          // Description
          Text(
            data['description'] ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),

          const SizedBox(height: 12),

          // Location
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(
                data['address'] ?? 'Location not set',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Submit Bid Button
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('service_requests')
                .doc(requestId)
                .collection('bids')
                .where('providerId', isEqualTo: uid)
                .snapshots(),
            builder: (context, bidSnapshot) {
              final alreadyBid = (bidSnapshot.data?.docs ?? []).isNotEmpty;

              if (alreadyBid) {
                final bidData = bidSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Bid submitted: ₹${bidData['amount']}',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }

              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showBidDialog(requestId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D4F),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.gavel, color: Colors.white),
                  label: const Text(
                    'Submit Bid',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showBidDialog(String requestId) async {
    final bidController = TextEditingController();
    final noteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Submit Your Bid',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: bidController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Your Rate (₹)',
                labelStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.currency_rupee, color: Color(0xFFFF4D4F)),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                labelStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.note_outlined, color: Color(0xFFFF4D4F)),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = bidController.text.trim();
                  if (amount.isEmpty) return;

                  final uid = _auth.currentUser?.uid;
                  await _firestore
                      .collection('service_requests')
                      .doc(requestId)
                      .collection('bids')
                      .add({
                    'providerId': uid,
                    'providerName': _providerData?['name'] ?? '',
                    'serviceType': _providerData?['serviceType'] ?? '',
                    'amount': int.tryParse(amount) ?? 0,
                    'note': noteController.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                    'status': 'pending',
                  });

                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D4F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Submit Bid',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
