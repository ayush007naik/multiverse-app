import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'live_delivery_tracking_screen.dart';

class LiveTrackingDashboard extends StatefulWidget {
  const LiveTrackingDashboard({super.key});

  @override
  State<LiveTrackingDashboard> createState() => _LiveTrackingDashboardState();
}

class _LiveTrackingDashboardState extends State<LiveTrackingDashboard> {
  GoogleMapController? _mapController;

  // Custom marker icons
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Row(
        children: [
          // Sidebar with live orders
          Container(
            width: 350,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1F3D),
              border: Border(right: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'LIVE DELIVERIES',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .where('status', whereIn: ['accepted', 'picked', 'on_the_way'])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final orders = snapshot.data!.docs;

                      if (orders.isEmpty) {
                        return const Center(
                          child: Text('No active deliveries', style: TextStyle(color: Colors.white54)),
                        );
                      }

                      return ListView.builder(
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index].data() as Map<String, dynamic>;
                          final orderId = orders[index].id;
                          return _buildOrderListItem(orderId, order);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main Map View
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('delivery_tracking').snapshots(),
              builder: (context, snapshot) {
                final markers = snapshot.hasData
                    ? _buildMarkers(snapshot.data!.docs)
                    : <Marker>{};

                return GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(31.5891, 76.9124),
                    zoom: 13,
                  ),
                  markers: markers,
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationEnabled: false,
                  zoomControlsEnabled: true,
                  mapType: MapType.normal,
                  style: _darkMapStyle,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers(List<QueryDocumentSnapshot> trackingDocs) {
    final Set<Marker> markers = {};
    for (var doc in trackingDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = data['lat'];
      final lng = data['lng'];
      final battery = data['batteryLevel'] ?? '--';

      if (lat != null && lng != null) {
        markers.add(Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          icon: _riderIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: 'Rider: ${doc.id}',
            snippet: 'Battery: $battery%',
          ),
        ));
      }
    }
    return markers;
  }

  Widget _buildOrderListItem(String orderId, Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final riderName = order['riderName'] ?? 'Unassigned';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveDeliveryTrackingScreen(
              orderId: orderId,
              orderData: order,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${orderId.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toString().toUpperCase(),
                    style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Customer: ${order['customerName'] ?? 'Guest'}',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
            const SizedBox(height: 4),
            Text('Rider: $riderName',
                style: const TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
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
