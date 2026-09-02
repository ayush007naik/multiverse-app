import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VendorOffersScreen extends StatelessWidget {
  const VendorOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Login required'));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Manage your offers and coupons',
                  style: TextStyle(color: Color(0xFFAAAAAA)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _createOffer(context, user.uid),
                icon: const Icon(Icons.add),
                label: const Text('Create Offer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildOffersList(user.uid)),
      ],
    );
  }

  Widget _buildOffersList(String vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('vendorId', isEqualTo: vendorId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final offers = docs.toList()
          ..sort((a, b) {
            final aData = a.data();
            final bData = b.data();
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

        if (offers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_offer, size: 80, color: Color(0xFFAAAAAA)),
                SizedBox(height: 16),
                Text(
                  'No offers yet',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index].data();
            return _buildOfferCard(offer, offers[index].id);
          },
        );
      },
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer, String offerId) {
    final isActive = offer['isActive'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isActive ? const Color(0xFF4CAF50) : Colors.red).withValues(
            alpha: 0.3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  offer['title'] ?? 'Offer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isActive ? const Color(0xFF4CAF50) : Colors.red)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isActive ? const Color(0xFF4CAF50) : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            offer['description'] ?? '',
            style: const TextStyle(color: Color(0xFFAAAAAA)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5722).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${offer['discount']}% OFF',
                  style: const TextStyle(
                    color: Color(0xFFFF5722),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _toggleOffer(offerId, isActive),
                icon: Icon(
                  isActive ? Icons.toggle_on : Icons.toggle_off,
                  color: isActive ? const Color(0xFF4CAF50) : Colors.red,
                  size: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createOffer(BuildContext context, String vendorId) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final discountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Create Offer',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Color(0xFFAAAAAA)),
              ),
            ),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Color(0xFFAAAAAA)),
              ),
            ),
            TextField(
              controller: discountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Discount %',
                labelStyle: TextStyle(color: Color(0xFFAAAAAA)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('offers').add({
                'vendorId': vendorId,
                'title': titleController.text,
                'description': descController.text,
                'discount': double.tryParse(discountController.text) ?? 0,
                'isActive': true,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleOffer(String offerId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('offers').doc(offerId).update({
      'isActive': !currentStatus,
    });
  }
}
