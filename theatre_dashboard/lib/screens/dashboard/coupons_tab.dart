import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:db_compat/db_compat.dart';
import '../../theme/cyberpunk_theme.dart';
import '../../services/theatre_service.dart';
import '../../widgets/common/neon_button.dart';

class CouponsTab extends StatefulWidget {
  const CouponsTab({super.key});

  @override
  State<CouponsTab> createState() => _CouponsTabState();
}

class _CouponsTabState extends State<CouponsTab> {
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theatreService = Provider.of<TheatreService>(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('OFFERS & COUPONS', style: Theme.of(context).textTheme.titleLarge),
              NeonButton(
                text: 'CREATE COUPON',
                icon: Icons.add_card,
                color: Colors.amberAccent,
                onPressed: () => _showCreateCouponDialog(context, theatreService),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: theatreService.getCoupons(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: CyberpunkTheme.primaryNeon));
                }
                final coupons = snapshot.data?.docs ?? [];
                if (coupons.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_offer_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 16),
                        const Text('NO COUPONS YET', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Create your first discount coupon.', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.8,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: coupons.length,
                  itemBuilder: (context, index) {
                    final data = coupons[index].data();
                    final docId = coupons[index].id;
                    return _buildCouponCard(context, docId, data, theatreService);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(BuildContext context, String id, Map<String, dynamic> data, TheatreService service) {
    final code = data['code'] ?? 'N/A';
    final description = data['description'] ?? '';
    final flatDiscount = data['discount'] ?? data['amount'] ?? data['value'] ?? 0;
    final percentDiscount = data['discountPercent'] ?? data['discountPercentage'] ?? 0;
    final isActive = data['isActive'] ?? true;
    final usedCount = data['usedCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CyberpunkTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.amberAccent.withValues(alpha: 0.3) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  code.toString().toUpperCase(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.amberAccent, letterSpacing: 2),
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(isActive ? 'Deactivate' : 'Activate'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
                onSelected: (value) async {
                  if (value == 'delete') {
                    await service.deleteCoupon(id);
                  } else if (value == 'toggle') {
                    await service.toggleCouponActive(id, !isActive);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                percentDiscount > 0 && flatDiscount <= 0
                    ? '$percentDiscount% OFF'
                    : '₹$flatDiscount OFF',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent),
              ),
              Text('Used: $usedCount', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateCouponDialog(BuildContext context, TheatreService service) {
    _codeCtrl.clear();
    _descCtrl.clear();
    _discountCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CyberpunkTheme.surface,
        title: const Text('CREATE COUPON', style: TextStyle(color: Colors.amberAccent)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Coupon Code (e.g. FIRST20)')),
              const SizedBox(height: 16),
              TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 16),
              TextField(
                controller: _discountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Flat Discount (₹)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
            onPressed: () async {
              final code = _codeCtrl.text.toUpperCase().trim();
              final discountStr = _discountCtrl.text.trim();
              
              if (code.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a coupon code')));
                return;
              }
              if (discountStr.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter flat discount amount')));
                return;
              }

              final discount = int.tryParse(discountStr);
              if (discount == null || discount <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Invalid discount amount')));
                return;
              }

              try {
                debugPrint('ACTION: Creating coupon: $code for theatre: ${service.currentUid}');
                
                await service.createCoupon({
                  'code': code,
                  'description': _descCtrl.text.trim(),
                  'discount': discount,
                  'isActive': true,
                  'usedCount': 0,
                  'type': 'movie',
                  'vendorId': service.currentUid, 
                });

                debugPrint('SUCCESS: Coupon created in Firestore');
                
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  // Use parent context's ScaffoldMessenger if still mounted
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Coupon created successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('ERROR: Failed to create coupon: $e');
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to create: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
  }
}
