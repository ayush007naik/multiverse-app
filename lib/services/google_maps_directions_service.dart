// Google Maps Directions API Service
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/logging_service.dart';

class GoogleMapsDirectionsService {
  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Get directions between two points
  static Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (_apiKey.isEmpty || _apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
      Log.w(
        'GoogleMapsDirectionsService',
        '⚠️ Google Maps API Key not set. Using keyless OSRM routing.',
      );
      return _getOsrmRoute(origin, destination);
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving'
        '&avoid=tolls'
        '&key=$_apiKey',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          return _parseDirections(data['routes'][0]);
        } else {
          Log.e(
            'GoogleMapsDirectionsService',
            '❌ Directions API error: ${data['status']}',
          );
          return _getOsrmRoute(origin, destination);
        }
      } else {
        Log.e(
          'GoogleMapsDirectionsService',
          '❌ HTTP error: ${response.statusCode}',
        );
        return _getOsrmRoute(origin, destination);
      }
    } catch (e) {
      Log.e(
        'GoogleMapsDirectionsService',
        '❌ Error fetching directions: $e',
        ex: e,
      );
      return _getOsrmRoute(origin, destination);
    }
  }

  /// Keyless routing via OSRM public server (no API key required).
  /// Returns real road distance/duration, falling back to a straight line
  /// only if OSRM itself fails.
  static Future<DirectionsResult?> _getOsrmRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=simplified&geometries=polyline&steps=false',
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final double distanceMeters =
              ((route['distance'] as num?)?.toDouble() ?? 0.0);
          final double durationSeconds =
              ((route['duration'] as num?)?.toDouble() ?? 0.0);

          if (distanceMeters > 0) {
            Log.i(
              'GoogleMapsDirectionsService',
              '✅ [OSRM] Road distance: ${(distanceMeters / 1000).toStringAsFixed(2)}km, '
              'duration: ${(durationSeconds / 60).toStringAsFixed(0)}min',
            );
            final encodedPolyline = route['geometry'] as String?;
            final points = encodedPolyline != null && encodedPolyline.isNotEmpty
                ? _decodePolyline(encodedPolyline)
                : <LatLng>[origin, destination];
            return DirectionsResult(
              polylinePoints: points,
              distanceText: '${(distanceMeters / 1000).toStringAsFixed(1)} km',
              distanceValue: distanceMeters.round(),
              durationText: '${(durationSeconds / 60).round()} mins',
              durationValue: durationSeconds.round(),
              startAddress: 'Shop Location',
              endAddress: 'Your Location',
            );
          }
        }
      }
      Log.w(
        'GoogleMapsDirectionsService',
        '⚠️ OSRM failed (${response.statusCode}), using straight-line fallback',
      );
      return _getFallbackRoute(origin, destination);
    } catch (e) {
      Log.e(
        'GoogleMapsDirectionsService',
        '❌ OSRM error: $e, using straight-line fallback',
        ex: e,
      );
      return _getFallbackRoute(origin, destination);
    }
  }

  /// Parse directions API response
  static DirectionsResult _parseDirections(Map<String, dynamic> route) {
    final legs = route['legs'][0];
    final overviewPolyline = route['overview_polyline']['points'];

    // Decode polyline
    final points = _decodePolyline(overviewPolyline);

    return DirectionsResult(
      polylinePoints: points,
      distanceText: legs['distance']['text'],
      distanceValue: legs['distance']['value'],
      durationText: legs['duration']['text'],
      durationValue: legs['duration']['value'],
      startAddress: legs['start_address'],
      endAddress: legs['end_address'],
    );
  }

  /// Fallback route (straight line) if API fails
  static DirectionsResult _getFallbackRoute(LatLng origin, LatLng destination) {
    final distance = _calculateDistance(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );

    return DirectionsResult(
      polylinePoints: [origin, destination],
      distanceText: '${(distance / 1000).toStringAsFixed(1)} km',
      distanceValue: distance.toInt(),
      durationText: '${(distance / 500 * 60).round()} mins',
      durationValue: (distance / 500 * 60).round(),
      startAddress: 'Shop Location',
      endAddress: 'Your Location',
    );
  }

  /// Calculate distance between two points (Haversine formula)
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  // Math helpers
  static double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  static double _sin(double x) =>
      x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  static double _cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;
  static double _sqrt(double x) {
    if (x == 0) return 0;
    double result = x;
    for (int i = 0; i < 10; i++) {
      result = (result + x / result) / 2;
    }
    return result;
  }

  static double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }

  static double _atan(double x) {
    return x - (x * x * x) / 3 + (x * x * x * x * x) / 5;
  }

  /// Decode Google polyline string
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}

/// Directions API result
class DirectionsResult {
  final List<LatLng> polylinePoints;
  final String distanceText;
  final int distanceValue; // in meters
  final String durationText;
  final int durationValue; // in seconds
  final String startAddress;
  final String endAddress;

  DirectionsResult({
    required this.polylinePoints,
    required this.distanceText,
    required this.distanceValue,
    required this.durationText,
    required this.durationValue,
    required this.startAddress,
    required this.endAddress,
  });
}
