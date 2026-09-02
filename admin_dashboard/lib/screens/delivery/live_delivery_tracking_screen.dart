import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LiveDeliveryTrackingScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const LiveDeliveryTrackingScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  State<LiveDeliveryTrackingScreen> createState() => _LiveDeliveryTrackingScreenState();
}

class _LiveDeliveryTrackingScreenState extends State<LiveDeliveryTrackingScreen> {
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};

  // Custom marker icons (placeholders for now, or use default)
  BitmapDescriptor? _riderIcon;
  BitmapDescriptor? _shopIcon;
  BitmapDescriptor? _customerIcon;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    _shopIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    _customerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    _riderIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    if (mounted) setState(() {});
  }

  double _getCoord(dynamic data, List<String> keys) {
    if (data == null) return 0.0;
    for (var key in keys) {
      if (data[key] != null) {
        if (data[key] is num) return (data[key] as num).toDouble();
        if (data[key] is String) return double.tryParse(data[key]) ?? 0.0;
      }
    }
    return 0.0;
  }

  Set<Marker> _buildMarkers(LatLng? riderPos, Map<String, dynamic> order) {
    final Set<Marker> markers = {};

    final sLat = _getCoord(order, ['shopLatitude', 'shopLat', 'vendorLat', 'lat']);
    final sLng = _getCoord(order, ['shopLongitude', 'shopLng', 'vendorLng', 'lng']);
    final cLat = _getCoord(order, ['customerLatitude', 'customerLat', 'drop_latitude', 'latitude']);
    final cLng = _getCoord(order, ['customerLongitude', 'customerLng', 'drop_longitude', 'longitude']);

    if (sLat != 0) {
      markers.add(Marker(
        markerId: const MarkerId('shop'),
        position: LatLng(sLat, sLng),
        icon: _shopIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(title: order['shopName'] ?? 'Shop'),
      ));
    }

    if (cLat != 0) {
      markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(cLat, cLng),
        icon: _customerIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(title: order['customerName'] ?? 'Customer'),
      ));
    }

    if (riderPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: riderPos,
        icon: _riderIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(title: order['riderName'] ?? 'Rider'),
        zIndex: 2,
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final riderId = widget.orderData['riderId'] ?? widget.orderData['deliveryPartnerId'];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F3D),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Track Order #${widget.orderId.substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(widget.orderData['status']?.toString().toUpperCase() ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.orange)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
        builder: (context, orderSnapshot) {
          if (!orderSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final order = orderSnapshot.data!.data() as Map<String, dynamic>? ?? {};

          return StreamBuilder<DocumentSnapshot>(
            stream: riderId != null
                ? FirebaseFirestore.instance.collection('delivery_tracking').doc(riderId).snapshots()
                : null,
            builder: (context, trackingSnapshot) {
              LatLng? riderPos;
              Map<String, dynamic>? trackData;
              if (trackingSnapshot.hasData && trackingSnapshot.data!.exists) {
                trackData = trackingSnapshot.data!.data() as Map<String, dynamic>;
                riderPos = LatLng(trackData['lat'], trackData['lng']);
              }

              final markers = _buildMarkers(riderPos, order);

              return Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: riderPos ?? const LatLng(31.5891, 76.9124),
                      zoom: 14,
                    ),
                    markers: markers,
                    polylines: _polylines,
                    onMapCreated: (controller) => _mapController = controller,
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                    mapType: MapType.normal,
                    style: _darkMapStyle,
                  ),
                  Positioned(
                    bottom: 24, left: 24, right: 24,
                    child: _buildRiderCard(order, riderPos, trackData),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRiderCard(Map<String, dynamic> order, LatLng? riderPos, Map<String, dynamic>? trackData) {
    final riderName = order['riderName'] ?? 'Searching for rider...';
    final riderPhone = order['riderPhone'] ?? '';
    final battery = trackData?['batteryLevel'] ?? '--';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange.withOpacity(0.2),
                child: const Icon(Icons.person, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(riderName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    if (riderPhone.isNotEmpty) Text(riderPhone, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  ],
                ),
              ),
              if (riderPhone.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green),
                  onPressed: () {},
                ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStat("Distance", riderPos != null ? "Calculating..." : "N/A"),
              _buildStat("ETA", riderPos != null ? "12 mins" : "N/A"),
              _buildStat("Battery", "$battery%"),
              _buildStat("Vehicle", order['vehicleType']?.toString().toUpperCase() ?? "BIKE"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  final String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#0A0E17"}]
  },
  {
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#1A1F2E"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [{"color": "#1A1F2E"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#000000"}]
  }
]
''';
}
