import 'package:flutter/material.dart';

import '../services/shop_service.dart';
import 'shop_detail_screen.dart';

class AllShopsScreen extends StatelessWidget {
  const AllShopsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shopService = ShopService();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text(
          'All Shops',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: shopService.streamActiveShops(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
            );
          }

          final shops = snapshot.data ?? [];
          if (shops.isEmpty) {
            return const Center(
              child: Text(
                'No active shops available',
                style: TextStyle(color: Color(0xFF888888)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final shop = shops[index];
              final imageUrl = (shop['image'] as String?)?.trim() ?? '';
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShopDetailScreen(shop: shop),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF272727)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(16),
                        ),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _shopFallback(shop),
                              )
                            : _shopFallback(shop),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shop['name'] as String? ?? 'Shop',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                shop['category'] as String? ?? 'General',
                                style: const TextStyle(
                                  color: Color(0xFFFF4D4F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ShopService.locationLabelFromData(shop),
                                style: const TextStyle(
                                  color: Color(0xFFAAAAAA),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(right: 14),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Color(0xFF555555),
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _shopFallback(Map<String, dynamic> shop) {
    return Container(
      width: 92,
      height: 92,
      color: Color(shop['color'] as int? ?? 0xFFFF4D4F).withValues(alpha: 0.15),
      child: Center(
        child: Text(
          shop['icon'] as String? ?? '🏪',
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }
}
