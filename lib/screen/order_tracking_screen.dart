import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/delivery_fee_calculator.dart';
import '../services/eta_calculator_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  GoogleMapController? _controller;
  LatLng _deliveryPos = const LatLng(31.7087, 76.9320);

  static const LatLng _fallbackShopPos = LatLng(31.7150, 76.9350);
  static const LatLng _fallbackUserPos = LatLng(31.7000, 76.9250);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, orderSnapshot) {
          if (!orderSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var orderData = orderSnapshot.data!.data() as Map<String, dynamic>?;
          if (orderData == null) {
            return const Center(
              child: Text(
                'Order not found',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          String status = orderData['status'] ?? 'placed';
          String? riderId = orderData['riderId'];
          final shopPos = _readOrderPosition(
            orderData,
            latKey: 'shopLat',
            lngKey: 'shopLng',
            fallback: _fallbackShopPos,
          );
          final userPos = _readAddressPosition(orderData['address']);
          final vehicle = DeliveryFeeCalculator.formatVehicle(
            DeliveryFeeCalculator.vehicleForDeliveryType(
              DeliveryFeeCalculator.normalizeDeliveryType(
                orderData['deliveryType'] as String?,
              ),
            ),
          );

          return StreamBuilder<DocumentSnapshot>(
            stream: riderId != null
                ? FirebaseFirestore.instance
                      .collection('delivery_locations')
                      .doc(riderId)
                      .snapshots()
                : const Stream.empty(),
            builder: (context, locationSnapshot) {
              if (locationSnapshot.hasData && locationSnapshot.data!.exists) {
                var locData =
                    locationSnapshot.data!.data() as Map<String, dynamic>;
                final lat = _readDouble(locData['lat']);
                final lng = _readDouble(locData['lng']);
                if (lat != null && lng != null) {
                  _deliveryPos = LatLng(lat, lng);
                  _controller?.animateCamera(
                    CameraUpdate.newLatLng(_deliveryPos),
                  );
                }
              }

              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: shopPos,
                      zoom: 15,
                    ),
                    onMapCreated: (c) => _controller = c,
                    markers: {
                      Marker(
                        markerId: const MarkerId('shop'),
                        position: shopPos,
                        infoWindow: const InfoWindow(title: 'Shop'),
                      ),
                      Marker(
                        markerId: const MarkerId('user'),
                        position: userPos,
                        infoWindow: const InfoWindow(title: 'You'),
                      ),
                      if (riderId != null)
                        Marker(
                          markerId: const MarkerId('delivery'),
                          position: _deliveryPos,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ),
                          infoWindow: InfoWindow(title: '$vehicle Partner'),
                        ),
                    },
                    style: _darkMapStyle,
                  ),
                  _buildStatusOverlay(status, vehicle, orderData, userPos),
                ],
              );
            },
          );
        },
      ),
    );
  }

  LatLng _readOrderPosition(
    Map<String, dynamic> orderData, {
    required String latKey,
    required String lngKey,
    required LatLng fallback,
  }) {
    final lat = _readDouble(orderData[latKey]);
    final lng = _readDouble(orderData[lngKey]);
    if (lat == null || lng == null) return fallback;
    return LatLng(lat, lng);
  }

  LatLng _readAddressPosition(dynamic address) {
    if (address is Map) {
      final lat = _readDouble(address['lat']);
      final lng = _readDouble(address['lng']);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return _fallbackUserPos;
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Widget _buildStatusOverlay(String status, String vehicle, Map<String, dynamic> orderData, LatLng userPos) {
    // Calculate ETA and distance
    String etaText = '';
    String distanceText = '';

    if (status == 'picked') {
      // Calculate ETA from rider to customer
      final etaData = ETACalculatorService().calculateDistanceAndETA(
        fromLat: _deliveryPos.latitude,
        fromLng: _deliveryPos.longitude,
        toLat: userPos.latitude,
        toLng: userPos.longitude,
        vehicleType: vehicle.toLowerCase(),
      );
      etaText = etaData['etaFormatted'];
      distanceText = etaData['distanceFormatted'];
    }

    bool isPrepared =
        status == 'ready' || status == 'picked' || status == 'delivered';
    bool isPicked = status == 'picked' || status == 'delivered';
    bool isDelivered = status == 'delivered';

    String statusText = 'Processing your order';
    if (status == 'preparing') statusText = 'Vendor is preparing your order';
    if (status == 'ready') statusText = 'Order is ready for pickup';
    if (status == 'picked') statusText = 'Rider has picked up your order';
    if (status == 'delivered') statusText = 'Order delivered! Enjoy.';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFFF4D4F),
                  child: Icon(Icons.delivery_dining, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        isDelivered
                            ? 'Thank you for ordering!'
                            : '$vehicle assigned for delivery',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      if (status == 'picked' && etaText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.blue, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'ETA: $etaText',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.location_on, color: Color(0xFFFF4D4F), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              distanceText,
                              style: const TextStyle(
                                color: Color(0xFFFF4D4F),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isDelivered)
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.green),
                    onPressed: () {},
                  ),
              ],
            ),
            const Divider(color: Color(0xFF333333), height: 32),
            _statusRow('Order Prepared', isPrepared),
            _statusRow('Picked up by partner', isPicked),
            _statusRow('Delivered', isDelivered),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String title, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDone ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(color: isDone ? Colors.white : Colors.grey),
          ),
        ],
      ),
    );
  }

  final String _darkMapStyle =
      '[{"elementType":"geometry","stylers":[{"color":"#212121"}]}]'; // Shortened for brevity
}
