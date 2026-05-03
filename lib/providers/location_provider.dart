import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/geocoding_service.dart';
import 'dart:developer' as developer;

class LocationProvider with ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String>? _currentAddress;
  String? _selectedAddress;
  final GeocodingService _geocodingService = GeocodingService();

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, String>? get currentAddress => _currentAddress;
  String? get selectedAddress => _selectedAddress;

  String get currentCityState {
    if (_selectedAddress != null && _selectedAddress!.isNotEmpty) {
      return _selectedAddress!;
    }
    
    if (_currentAddress == null) return '';
    final city = _currentAddress!['city'] ?? '';
    final state = _currentAddress!['state'] ?? '';
    
    if (city.isEmpty && state.isEmpty) return '';
    if (city.isEmpty) return state;
    if (state.isEmpty) return city;
    if (city == 'Location unavailable') return '';

    return '$city, $state';
  }

  void setSelectedAddress(String address) {
    _selectedAddress = address;
    notifyListeners();
  }

  /// Updates stored coordinates for distance calculations
  void updateCoordinates(double latitude, double longitude) {
    // Store coordinates in position object
    _currentPosition = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
    notifyListeners();
  }

  /// Returns current position with latitude and longitude
  /// Returns null if location cannot be determined
  Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        developer.log('📍 Location services are disabled', 
            name: 'LocationProvider', 
            error: 'Location services disabled');
        throw Exception('Location services are disabled. Please enable them in settings.');
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        developer.log('📍 Requesting location permission', name: 'LocationProvider');
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        developer.log('📍 Location permission denied', name: 'LocationProvider', 
            error: 'User denied location permission');
        throw Exception('Location permission denied');
      }

      if (permission == LocationPermission.deniedForever) {
        developer.log('📍 Location permission denied forever', name: 'LocationProvider', 
            error: 'User denied location permission permanently');
        throw Exception('Location permissions are permanently denied. Please enable them in app settings.');
      }

      // Get position with proper timeout handling
      Position? position;
      try {
        developer.log('📍 Getting high accuracy position', name: 'LocationProvider');
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        developer.log('📍 High accuracy position obtained: ${position?.latitude}, ${position?.longitude}', 
            name: 'LocationProvider');
      } catch (e) {
        developer.log('📍 High accuracy location failed: $e', name: 'LocationProvider');
        // Fallback to last known or low accuracy
        position = await Geolocator.getLastKnownPosition() ?? 
                   await Geolocator.getCurrentPosition(
                     desiredAccuracy: LocationAccuracy.low,
                   );
        developer.log('📍 Low accuracy position obtained: ${position?.latitude}, ${position?.longitude}', 
            name: 'LocationProvider');
      }

      if (position == null) {
        developer.log('📍 Could not detect location', name: 'LocationProvider', 
            error: 'No position available');
        throw Exception('Could not detect your location. Please select manually.');
      }

      return position;
      
    } catch (e) {
      developer.log('📍 Error getting position: $e', name: 'LocationProvider', 
          error: e);
      rethrow;
    }
  }

  /// Updates location and gets address information
  Future<void> updateLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get current position
      final position = await getCurrentPosition();
      
      if (position == null) {
        throw Exception('Could not detect your location. Please select manually.');
      }

      _currentPosition = position;

      // Get address from coordinates
      developer.log('📍 Getting address for coordinates: ${position.latitude}, ${position.longitude}', 
          name: 'LocationProvider');
      final addressData = await _geocodingService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // Handle fallback cases gracefully - always store what we get
      if (addressData['city'] == 'Location unavailable' && 
          addressData['state'] == 'Location unavailable') {
        developer.log('📍 Geocoding failed, using fallback coordinates', name: 'LocationProvider');
        // Store the fallback coordinates but don't throw error
        _currentAddress = addressData;
      } else if (addressData['pincode'] == '000000' || addressData['city'] == 'Unknown City') {
        developer.log('📍 Inaccurate address detected, using fallback', name: 'LocationProvider');
        // Use fallback coordinates instead of throwing
        _currentAddress = {
          'city': 'Location unavailable',
          'state': 'Location unavailable',
          'area': 'Latitude: ${position.latitude}, Longitude: ${position.longitude}',
          'pincode': '000000',
        };
      } else {
        _currentAddress = addressData;
      }
      // Clear manual selection when using GPS
      _selectedAddress = null;
      
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      developer.log('📍 Error updating location: $e', name: 'LocationProvider', 
          error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
