import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Customer Side - Live Order Tracking Screen
/// Reads riderLat, riderLng from order document
/// Shows live tracking on map
class CustomerLiveTrackingScreen extends StatefulWidget {
  final String orderId;

  const CustomerLiveTrackingScreen({super.key, required this.orderId});

  @override
  State<CustomerLiveTrackingScreen> createState() =>
      _CustomerLiveTrackingScreenState();
}

class _CustomerLiveTrackingScreenState
    extends State<CustomerLiveTrackingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  LatLng? _riderPosition;
  LatLng? _customerPosition;
  Set<Marker> _markers = {};
  String _orderStatus = '';

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    try {
      final orderDoc =
          await _firestore.collection('orders').doc(widget.orderId).get();

      if (orderDoc.exists) {
        final data = orderDoc.data()!;
        setState(() {
          _orderStatus = data['status'] ?? 'pending';

          // Get customer location from order
          if (data['customerLat'] != null && data['customerLng'] != null) {
            _customerPosition = LatLng(
              data['customerLat'].toDouble(),
              data['customerLng'].toDouble(),
            );
          }

          // Get rider location if available
          if (data['riderLat'] != null && data['riderLng'] != null) {
            _riderPosition = LatLng(
              data['riderLat'].toDouble(),
              data['riderLng'].toDouble(),
            );
          }

          _updateMarkers();
        });

        // Center map on customer location
        if (_customerPosition != null && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_customerPosition!, 15),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading order details: $e');
    }
  }

  void _updateMarkers() {
    _markers.clear();

    // Customer marker
    if (_customerPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: _customerPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    // Rider marker (only if on the way)
    if (_riderPosition != null && _orderStatus == 'on_the_way') {
      _markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: _riderPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: const InfoWindow(title: 'Rider Location'),
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text(
          'Live Tracking',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore
                .collection('orders')
                .doc(widget.orderId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                );
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase().replaceAll('_', ' '),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Map
          Expanded(
            flex: 3,
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('orders')
                  .doc(widget.orderId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF4D4F)),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final status = data['status'] ?? '';

                // Update rider position if on the way
                if (status == 'on_the_way' &&
                    data['riderLat'] != null &&
                    data['riderLng'] != null) {
                  final newRiderPos = LatLng(
                    data['riderLat'].toDouble(),
                    data['riderLng'].toDouble(),
                  );

                  if (_riderPosition != newRiderPos) {
                    _riderPosition = newRiderPos;
                    _updateMarkers();

                    // Animate camera to follow rider
                    if (_mapController != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLng(_riderPosition!),
                      );
                    }
                  }
                }

                if (_customerPosition == null) {
                  return const Center(
                    child: Text(
                      'Location not available',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                return GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _customerPosition!,
                    zoom: 14,
                  ),
                  markers: _markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                );
              },
            ),
          ),

          // Bottom Status Panel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('orders')
                  .doc(widget.orderId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator(
                    color: Color(0xFFFF4D4F),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'pending';
                final riderName = data['riderName'] ?? 'Your Rider';
                final riderPhone = data['riderPhone'] ?? '';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status title
                    Text(
                      _getStatusTitle(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getStatusDescription(status),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),

                    if (status == 'on_the_way') ...[
                      const SizedBox(height: 16),
                      // Rider info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFFF4D4F),
                              child: Icon(Icons.delivery_dining,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    riderName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (riderPhone.isNotEmpty)
                                    Text(
                                      riderPhone,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (riderPhone.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.phone,
                                    color: Color(0xFFFF4D4F)),
                                onPressed: () {
                                  // TODO: Implement phone call
                                },
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Status progress indicator
                    _buildStatusProgress(status),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusProgress(String currentStatus) {
    final statuses = ['accepted', 'picked', 'on_the_way', 'delivered'];
    final currentIndex = statuses.indexOf(currentStatus);

    return Row(
      children: statuses.asMap().entries.map((entry) {
        final index = entry.key;
        final status = entry.value;
        final isActive = index <= currentIndex;

        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isActive
                    ? const Color(0xFFFF4D4F)
                    : Colors.grey.withOpacity(0.3),
                child: Icon(
                  _getStatusIcon(status),
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey,
                  fontSize: 8,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check;
      case 'picked':
        return Icons.shopping_bag;
      case 'on_the_way':
        return Icons.directions_bike;
      case 'delivered':
        return Icons.done_all;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return const Color(0xFFFF4D4F);
      case 'picked':
        return Colors.blue;
      case 'on_the_way':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'accepted':
        return 'Order Accepted';
      case 'picked':
        return 'Order Picked Up';
      case 'on_the_way':
        return 'Rider on the Way!';
      case 'delivered':
        return 'Order Delivered!';
      default:
        return 'Order Processing';
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'accepted':
        return 'Your order is being prepared';
      case 'picked':
        return 'Rider has picked up your order';
      case 'on_the_way':
        return 'Your order is on the way to you';
      case 'delivered':
        return 'Your order has been delivered successfully';
      default:
        return 'Please wait...';
    }
  }
}
