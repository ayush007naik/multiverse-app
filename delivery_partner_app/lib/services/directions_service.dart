import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsService {
  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  /// Returns real road route points between origin and destination.
  ///
  /// Priority:
  ///  1. Google Directions API (only if a valid key was passed via --dart-define).
  ///  2. Keyless OSRM public router (no API key required, real road geometry).
  ///  3. Straight line as last resort (should rarely happen).
  static Future<List<LatLng>> getRoutePoints(LatLng origin, LatLng destination) async {
    // 1. Google Directions API
    if (_apiKey.isNotEmpty && _apiKey != 'YOUR_GOOGLE_MAPS_API_KEY') {
      final googlePoints = await _getGoogleRoutePoints(origin, destination);
      if (googlePoints.length > 2) return googlePoints;
    }

    // 2. Keyless OSRM fallback
    final osrmPoints = await _getOsrmRoutePoints(origin, destination);
    if (osrmPoints.length > 2) return osrmPoints;

    // 3. Straight line fallback
    return [origin, destination];
  }

  static Future<List<LatLng>> _getGoogleRoutePoints(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final response = await http.get(Uri.parse(
        '$_baseUrl?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving&key=$_apiKey',
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final polyline = data['routes'][0]['overview_polyline']['points'];
          return _decodePolyline(polyline);
        }
      }
    } catch (e) {
      print('Error fetching Google directions: $e');
    }
    return [origin, destination];
  }

  /// Keyless routing via OSRM public server — returns real road geometry
  /// without needing a Google Maps API key.
  static Future<List<LatLng>> _getOsrmRoutePoints(
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
          final encodedPolyline = data['routes'][0]['geometry'] as String?;
          if (encodedPolyline != null && encodedPolyline.isNotEmpty) {
            return _decodePolyline(encodedPolyline);
          }
        }
      }
    } catch (e) {
      print('Error fetching OSRM route: $e');
    }
    return [origin, destination];
  }

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
