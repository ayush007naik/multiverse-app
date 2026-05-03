import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../services/shop_service.dart';

class MapScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? shops;
  const MapScreen({super.key, this.shops});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  Position? _currentPosition;
  final Set<Marker> _markers = {};

  // Default location: Mandi, HP
  static const LatLng _mandiCenter = LatLng(31.7087, 76.9320);

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadShopMarkers();
  }

  Future<void> _checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _currentPosition = await Geolocator.getCurrentPosition();
    if (_controller != null && _currentPosition != null) {
      _controller!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
    setState(() {});
  }

  void _loadShopMarkers() {
    final shopsToMark =
        widget.shops ??
        [
          {'name': 'Sharma Hardware', 'category': 'Hardware'},
          {'name': 'Mandi Fashion Hub', 'category': 'Clothing'},
          {'name': 'Shiv Medical Store', 'category': 'Pharmacy'},
        ];

    for (var i = 0; i < shopsToMark.length; i++) {
      var shop = shopsToMark[i];
      final lat =
          ShopService.readCoordinate(shop, const ['lat', 'latitude']) ??
          (_mandiCenter.latitude + (0.005 * (i - 1)));
      final lng =
          ShopService.readCoordinate(shop, const ['lng', 'longitude']) ??
          (_mandiCenter.longitude + (0.005 * (i - 1)));

      _markers.add(
        Marker(
          markerId: MarkerId((shop['id'] ?? shop['name']).toString()),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: shop['name'],
            snippet: ShopService.locationLabelFromData(shop),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text(
          'Shops Near Me',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _mandiCenter,
          zoom: 14,
        ),
        onMapCreated: (controller) => _controller = controller,
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        style: _darkMapStyle,
      ),
    );
  }

  final String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#000000"
      }
    ]
  }
]
''';
}
