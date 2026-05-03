// 📁 lib/screens/tracking_screen.dart
// ✅ Live Tracking Screen for MULTIVERSE — Mandi, Himachal Pradesh

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math';

class TrackingScreen extends StatefulWidget {
  final String orderId;
  const TrackingScreen({super.key, required this.orderId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  GoogleMapController? _mapController;
  Timer? _timer;

  // 📍 Mandi, HP coordinates
  static const LatLng _shopLocation =
  LatLng(31.7084, 76.9320); // Mandi Bazaar
  static const LatLng _customerLocation =
  LatLng(31.7180, 76.9450); // Customer location

  // 🛵 Delivery boy starts near shop
  LatLng _deliveryBoyPos = const LatLng(31.7090, 76.9330);

  int _etaMinutes = 18;
  int _step = 1; // 0=confirmed, 1=packing, 2=picked, 3=on way, 4=delivered
  bool _isDelivered = false;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Delivery boy info
  final Map<String, String> _deliveryBoy = {
    'name': 'Ravi Kumar',
    'phone': '+91 98765 43210',
    'rating': '4.8',
    'vehicle': 'HP 34 AB 1234',
  };

  @override
  void initState() {
    super.initState();
    _setupMarkers();
    _setupPolyline();
    _simulateDelivery();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _setupMarkers() {
    _markers.clear();
    _markers.addAll([
      // 🏪 Shop marker
      Marker(
        markerId: const MarkerId('shop'),
        position: _shopLocation,
        infoWindow: const InfoWindow(title: '🏪 Sharma Hardware Store'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
      // 🏠 Customer marker
      Marker(
        markerId: const MarkerId('customer'),
        position: _customerLocation,
        infoWindow: const InfoWindow(title: '🏠 Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      // 🛵 Delivery boy marker
      Marker(
        markerId: const MarkerId('delivery'),
        position: _deliveryBoyPos,
        infoWindow: InfoWindow(title: '🛵 ${_deliveryBoy['name']}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    ]);
  }

  void _setupPolyline() {
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_shopLocation, _customerLocation],
        color: const Color(0xFFFF4D4F),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );
  }

  // 🎬 Simulate delivery boy moving
  void _simulateDelivery() {
    int tick = 0;
    _timer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted) return;
      tick++;

      // Move delivery boy towards customer
      final lat = _deliveryBoyPos.latitude +
          (_customerLocation.latitude - _deliveryBoyPos.latitude) * 0.1;
      final lng = _deliveryBoyPos.longitude +
          (_customerLocation.longitude - _deliveryBoyPos.longitude) * 0.1;

      setState(() {
        _deliveryBoyPos = LatLng(lat, lng);
        _etaMinutes = max(1, _etaMinutes - 1);

        // Update step
        if (tick == 2) _step = 2; // Picked up
        if (tick == 4) _step = 3; // On the way
        if (_etaMinutes <= 1) {
          _step = 4;
          _isDelivered = true;
          t.cancel();
        }

        _setupMarkers();
      });

      // Animate camera to delivery boy
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_deliveryBoyPos),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // 🗺️ Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                (_shopLocation.latitude + _customerLocation.latitude) / 2,
                (_shopLocation.longitude + _customerLocation.longitude) / 2,
              ),
              zoom: 14.5,
            ),
            onMapCreated: (c) => _mapController = c,
            markers: _markers,
            polylines: _polylines,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            style: _darkMapStyle,
          ),

          // 🔝 Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF272727)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF272727)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded,
                              color: Color(0xFFFF4D4F), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Order #${widget.orderId}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D4F).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isDelivered ? 'Delivered ✅' : '$_etaMinutes min',
                              style: const TextStyle(
                                color: Color(0xFFFF4D4F),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 📋 Bottom Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF111111),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: Color(0xFF1E1E1E)),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // 🚦 Progress Steps
                  _buildProgressSteps(),

                  const SizedBox(height: 20),

                  if (_isDelivered) _buildDeliveredCard() else _buildDeliveryBoyCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🚦 Progress Steps
  Widget _buildProgressSteps() {
    final steps = [
      {'icon': '✅', 'label': 'Confirmed'},
      {'icon': '🏪', 'label': 'Packing'},
      {'icon': '🛵', 'label': 'Picked Up'},
      {'icon': '⚡', 'label': 'On the Way'},
      {'icon': '🏠', 'label': 'Delivered'},
    ];

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Line
          final done = i ~/ 2 < _step;
          return Expanded(
            child: Container(
              height: 2,
              color: done
                  ? const Color(0xFFFF4D4F)
                  : const Color(0xFF272727),
            ),
          );
        }
        final idx = i ~/ 2;
        final done = idx <= _step;
        return Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: done
                    ? const Color(0xFFFF4D4F).withValues(alpha: 0.15)
                    : const Color(0xFF1E1E1E),
                shape: BoxShape.circle,
                border: Border.all(
                  color: done
                      ? const Color(0xFFFF4D4F)
                      : const Color(0xFF272727),
                  width: done ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  steps[idx]['icon']!,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[idx]['label']!,
              style: TextStyle(
                color: done ? Colors.white : const Color(0xFF555555),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }),
    );
  }

  // 🛵 Delivery Boy Card
  Widget _buildDeliveryBoyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272727)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D4F).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🛵', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _deliveryBoy['name']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFB300), size: 13),
                        const SizedBox(width: 3),
                        Text(
                          _deliveryBoy['rating']!,
                          style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _deliveryBoy['vehicle']!,
                          style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Call button
              GestureDetector(
                onTap: () {
                  // TODO: Launch phone call
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.call_rounded,
                      color: Color(0xFF4CAF50), size: 22),
                ),
              ),
              const SizedBox(width: 10),
              // Chat button
              GestureDetector(
                onTap: () {
                  // TODO: Open chat
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF2196F3), size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ETA bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D4F).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    color: Color(0xFFFF4D4F), size: 18),
                const SizedBox(width: 10),
                Text(
                  'Arriving in $_etaMinutes minutes',
                  style: const TextStyle(
                    color: Color(0xFFFF4D4F),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Text('🛵', style: TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Delivered Card
  Widget _buildDeliveredCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          const Text(
            'Order Delivered!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hope you enjoy your order!\nRate your experience below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF888888), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () {},
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.star_rounded,
                      color: Color(0xFFFFB300), size: 36),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Submit Rating',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌙 Dark map style
  static const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
]
''';
}