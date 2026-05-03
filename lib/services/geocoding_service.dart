import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';

class GeocodingService {
  /// Converts coordinates to placemark and extracts city/state
  /// Returns fallback coordinates if geocoding fails
  Future<Map<String, String>> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      // Verify internet connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        developer.log('📡 No internet connectivity detected', 
            name: 'GeocodingService', 
            error: 'No internet connection');
        // Return fallback coordinates when no internet
        return {
          'city': 'Location unavailable',
          'state': 'Location unavailable',
          'area': 'Latitude: $latitude, Longitude: $longitude',
          'pincode': '000000',
        };
      }

      // Try geocoding with timeout
      final placemarks = await placemarkFromCoordinates(latitude, longitude).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          developer.log('📡 Geocoding timeout after 8 seconds', 
              name: 'GeocodingService', 
              error: 'Geocoding timeout');
          // Return fallback coordinates on timeout
          return [];
        },
      );

      if (placemarks.isEmpty) {
        developer.log('📡 No placemarks returned from geocoding', 
            name: 'GeocodingService');
        // Return fallback coordinates when no placemarks
        return {
          'city': 'Location unavailable',
          'state': 'Location unavailable',
          'area': 'Latitude: $latitude, Longitude: $longitude',
          'pincode': '000000',
        };
      }

      final placemark = placemarks.first;
      
      final city = placemark.locality ?? placemark.subAdministrativeArea ?? '';
      final state = placemark.administrativeArea ?? '';
      final area = placemark.subLocality ?? placemark.thoroughfare ?? placemark.name ?? '';
      final pincode = placemark.postalCode ?? '';

      if (city.isEmpty && state.isEmpty) {
        developer.log('📡 Could not determine city or state from placemark', 
            name: 'GeocodingService');
        // Return fallback coordinates when city/state cannot be determined
        return {
          'city': 'Location unavailable',
          'state': 'Location unavailable',
          'area': 'Latitude: $latitude, Longitude: $longitude',
          'pincode': '000000',
        };
      }

      return {
        'city': city.isNotEmpty ? city : 'Unknown City',
        'state': state.isNotEmpty ? state : 'Unknown State',
        'area': area.isNotEmpty ? area : 'Unknown Area',
        'pincode': pincode.isNotEmpty ? pincode : '000000',
      };
    } catch (e) {
      developer.log('📡 Geocoding error: $e', 
          name: 'GeocodingService', 
          error: e);
      // Return fallback coordinates on any error
      return {
        'city': 'Location unavailable',
        'state': 'Location unavailable',
        'area': 'Latitude: $latitude, Longitude: $longitude',
        'pincode': '000000',
      };
    }
  }

  /// Gets formatted city and state string
  Future<String> getCityStateString(double latitude, double longitude) async {
    final address = await getAddressFromCoordinates(latitude, longitude);
    final city = address['city'] ?? 'Location unavailable';
    final state = address['state'] ?? 'Location unavailable';

    if (city == 'Location unavailable' || state == 'Location unavailable') {
      return 'Location unavailable';
    }

    return '$city, $state';
  }
}