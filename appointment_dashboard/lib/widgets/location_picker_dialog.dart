import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';

class LocationPickerDialog extends StatefulWidget {
  final LatLng initialLocation;
  final bool myLocationEnabled;

  const LocationPickerDialog({
    super.key,
    this.initialLocation = const LatLng(19.0760, 72.8777), // Default to Mumbai
    this.myLocationEnabled = false,
  });

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  late LatLng _selectedLocation;
  CameraPosition? _cameraPosition;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _cameraPosition = CameraPosition(target: _selectedLocation, zoom: 15);
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!mounted) return;
    setState(() {
      _mapReady = true;
    });
  }

  void _onCameraMove(CameraPosition position) {
    // Only store the position here — no setState while the map is moving,
    // which avoids rebuilding during the first frame and crashing the dialog.
    _cameraPosition = position;
  }

  void _onCameraIdle() {
    if (!mounted) return;
    final target = _cameraPosition?.target;
    if (target == null) return;
    setState(() {
      _selectedLocation = target;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pick Location',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    if (!_mapReady)
                      const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
                      ),
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _selectedLocation,
                        zoom: 15,
                      ),
                      onMapCreated: _onMapCreated,
                      onCameraMove: _onCameraMove,
                      onCameraIdle: _onCameraIdle,
                      myLocationEnabled: widget.myLocationEnabled,
                      myLocationButtonEnabled: widget.myLocationEnabled,
                      mapToolbarEnabled: false,
                      zoomControlsEnabled: false,
                    ),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 35),
                        child: Icon(
                          Icons.location_on,
                          color: AppTheme.primaryOrange,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _mapReady
                          ? () => Navigator.pop(context, _selectedLocation)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('CONFIRM LOCATION', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
