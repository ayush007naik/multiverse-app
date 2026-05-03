import 'package:flutter/material.dart';

class PropertyDetailScreen extends StatelessWidget {
  final Map<String, dynamic> property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D4F).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              property['type'],
                              style: const TextStyle(color: Color(0xFFFF4D4F), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          Text(
                            property['price'],
                            style: const TextStyle(color: Color(0xFFFF4D4F), fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        property['title'],
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.grey, size: 16),
                          const SizedBox(width: 4),
                          Text(property['location'], style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 25),
                      const Text(
                        'Description',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Beautiful property located in the heart of ${property['location']}. Features modern architecture, spacious rooms, and premium amenities. Perfect for those looking for quality and comfort.',
                        style: const TextStyle(color: Color(0xFFAAAAAA), height: 1.5),
                      ),
                      const SizedBox(height: 25),
                      _buildFeatures(),
                      const SizedBox(height: 100), // Space for bottom button
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildBottomAction(context),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300,
      backgroundColor: const Color(0xFF0D0D0D),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Image.network(
          property['image'],
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Features',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _featureIcon(Icons.bed, '3 Beds'),
            _featureIcon(Icons.bathtub, '2 Baths'),
            _featureIcon(Icons.square_foot, '1200 sqft'),
            _featureIcon(Icons.garage, '1 Park'),
          ],
        ),
      ],
    );
  }

  Widget _featureIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFFF4D4F), size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
        ),
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contacting owner...'), backgroundColor: Color(0xFFFF4D4F)),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4D4F),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Contact Owner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        ),
      ),
    );
  }
}
