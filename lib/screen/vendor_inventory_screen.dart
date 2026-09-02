import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/vendor_product_service.dart';

class VendorInventoryScreen extends StatefulWidget {
  const VendorInventoryScreen({super.key});

  @override
  State<VendorInventoryScreen> createState() => _VendorInventoryScreenState();
}

class _VendorInventoryScreenState extends State<VendorInventoryScreen> {
  final _productService = VendorProductService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Login required'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInventoryStats(user.uid),
          const SizedBox(height: 24),
          _buildInventoryList(user.uid),
        ],
      ),
    );
  }

  Widget _buildInventoryStats(String vendorId) {
    return FutureBuilder<Map<String, int>>(
      future: _productService.getInventoryStats(vendorId),
      builder: (context, snapshot) {
        final stats =
            snapshot.data ?? {'inStock': 0, 'lowStock': 0, 'outOfStock': 0};

        return Row(
          children: [
            _statCard(
              'In Stock',
              stats['inStock'] ?? 0,
              const Color(0xFF4CAF50),
            ),
            const SizedBox(width: 16),
            _statCard(
              'Low Stock',
              stats['lowStock'] ?? 0,
              const Color(0xFFFF9800),
            ),
            const SizedBox(width: 16),
            _statCard('Out of Stock', stats['outOfStock'] ?? 0, Colors.red),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Color(0xFFAAAAAA))),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryList(String vendorId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('stock', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index].data();
            final productId = products[index].id;
            return _buildInventoryItem(product, productId);
          },
        );
      },
    );
  }

  Widget _buildInventoryItem(Map<String, dynamic> product, String productId) {
    final stock = product['stock'] ?? 0;
    final status = stock == 0
        ? 'out_of_stock'
        : stock <= 10
        ? 'low_stock'
        : 'in_stock';
    final color = status == 'out_of_stock'
        ? Colors.red
        : status == 'low_stock'
        ? const Color(0xFFFF9800)
        : const Color(0xFF4CAF50);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['title'] ?? 'Product',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Stock: $stock',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _updateStock(productId, stock),
            icon: const Icon(Icons.edit, color: Color(0xFFFF5722)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStock(String productId, int currentStock) async {
    final controller = TextEditingController(text: currentStock.toString());

    final newStock = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Update Stock',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'New Stock Quantity',
            labelStyle: TextStyle(color: Color(0xFFAAAAAA)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(controller.text)),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (newStock != null && newStock >= 0) {
      await _productService.updateStock(productId, newStock);
    }
  }
}
