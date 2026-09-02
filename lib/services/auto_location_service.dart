import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/geocoding_service.dart';
import '../core/logging_service.dart';

/// Auto Location Detection Service
/// Handles:
/// - Auto GPS detection on app launch
/// - Location permission management
/// - Save/restore last location via SharedPreferences
/// - Background location refresh
/// - Fallback system when GPS fails
class AutoLocationService extends ChangeNotifier {
  static final AutoLocationService _instance = AutoLocationService._internal();
  factory AutoLocationService() => _instance;
  AutoLocationService._internal();

  final GeocodingService _geocodingService = GeocodingService();

  // Location state
  Position? _currentPosition;
  Map<String, String>? _currentAddress;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  // SharedPreferences keys
  static const String _kLastLatitude = 'last_latitude';
  static const String _kLastLongitude = 'last_longitude';
  static const String _kLastAddress = 'last_address';
  static const String _kLastTimestamp = 'last_timestamp';
  static const String _kPermissionAsked = 'location_permission_asked';

  // Getters
  Position? get currentPosition => _currentPosition;
  Map<String, String>? get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double? get latitude => _currentPosition?.latitude;
  double? get longitude => _currentPosition?.longitude;

  String get city => _currentAddress?['city'] ?? 'Detecting...';
  String get area => _currentAddress?['area'] ?? '';
  String get state => _currentAddress?['state'] ?? '';

  String get cityState {
    final c = _currentAddress?['city'] ?? '';
    final s = _currentAddress?['state'] ?? '';
    final a = _currentAddress?['area'] ?? '';
    final street = _currentAddress?['street'] ?? '';
    final houseNo = _currentAddress?['houseNo'] ?? '';
    final fullAddr = _currentAddress?['fullAddress'] ?? '';

    if (fullAddr.isNotEmpty) {
      final firstLine = fullAddr.split('\n').first.trim();
      if (firstLine.isNotEmpty) return firstLine;
    }

    final parts = <String>[];
    if (houseNo.isNotEmpty) parts.add(houseNo);
    if (street.isNotEmpty) parts.add(street);
    if (a.isNotEmpty && a != 'Unknown Area') parts.add(a);
    if (c.isNotEmpty) parts.add(c);

    if (parts.length >= 2) return parts.take(2).join(', ');
    if (parts.isNotEmpty) return parts.first;
    if (c.isNotEmpty) return '$c, $s';
    return 'Detecting...';
  }

  // ============================================================================
  // INITIALIZATION - Call this in main() or app startup
  // ============================================================================

  /// Initialize auto location detection
  /// Call this when app starts
  Future<void> initialize() async {
    Log.i('AutoLocation', '📍 [AutoLocation] Initializing...');

    // Step 1: Load saved location immediately
    await _loadSavedLocation();

    // Step 2: Check permission
    final hasPermission = await _checkAndRequestPermission();

    if (hasPermission) {
      // Step 3: Auto-detect GPS location
      await _detectGPSLocation();
    }

    // Step 4: Start background refresh (every 5 minutes)
    _startBackgroundRefresh();

    Log.i('AutoLocation', '📍 [AutoLocation] Initialization complete');
  }

  // ============================================================================
  // PERMISSION MANAGEMENT
  // ============================================================================

  /// Check and request location permission
  /// Returns true if permission granted
  Future<bool> _checkAndRequestPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final permissionAsked = prefs.getBool(_kPermissionAsked) ?? false;

      LocationPermission permission = await Geolocator.checkPermission();

      // If permission denied and never asked before, request it
      if (permission == LocationPermission.denied && !permissionAsked) {
        Log.i(
          'AutoLocation',
          '📍 [AutoLocation] Requesting permission (first time)',
        );
        permission = await Geolocator.requestPermission();
        await prefs.setBool(_kPermissionAsked, true);
      }

      if (permission == LocationPermission.denied) {
        Log.i('AutoLocation', '📍 [AutoLocation] Permission denied');
        _errorMessage = 'Location permission denied';
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        Log.i('AutoLocation', '📍 [AutoLocation] Permission denied forever');
        _errorMessage = 'Enable location in app settings';
        return false;
      }

      Log.i(
        'AutoLocation',
        '📍 [AutoLocation] Permission granted: $permission',
      );
      return true;
    } catch (e) {
      Log.i('AutoLocation', '📍 [AutoLocation] Permission check error: $e');
      return false;
    }
  }

  // ============================================================================
  // GPS DETECTION
  // ============================================================================

  /// Detect GPS location automatically
  Future<void> _detectGPSLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if location services enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Log.i('AutoLocation', '📍 [AutoLocation] Location services disabled');
        _errorMessage = 'Enable location services';
        _isLoading = false;
        notifyListeners();
        return;
      }

      Position? position;

      // Try high accuracy first
      try {
        Log.i(
          'AutoLocation',
          '📍 [AutoLocation] Getting high accuracy position...',
        );
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        Log.i(
          'AutoLocation',
          '📍 [AutoLocation] High accuracy failed, using fallback',
        );
        // Fallback to last known position or low accuracy
        position =
            await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 15),
            );
      }

      // position is non-null because of getCurrentPosition
      Log.i(
        'AutoLocation',
        '📍 [AutoLocation] GPS position: ${position.latitude}, ${position.longitude}',
      );
      _currentPosition = position;

      // Convert coordinates to address
      await _geocodePosition(position);

      // Save to local storage
      await _saveLocation();
    } catch (e) {
      Log.i('AutoLocation', '📍 [AutoLocation] GPS detection error: $e');
      _errorMessage = e.toString();

      // Fallback: keep using last saved location
      if (_currentPosition == null) {
        await _loadSavedLocation();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // GEOCODING - Convert coordinates to city/area/state
  // ============================================================================

  /// Convert GPS coordinates to readable address
  Future<void> _geocodePosition(Position position) async {
    try {
      Log.i('AutoLocation', '📍 [AutoLocation] Geocoding coordinates...');

      final addressData = await _geocodingService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      _currentAddress = addressData;

      Log.i(
        'AutoLocation',
        '📍 [AutoLocation] Address: ${addressData['city']}, ${addressData['state']}',
      );
    } catch (e) {
      Log.i('AutoLocation', '📍 [AutoLocation] Geocoding error: $e');
      _currentAddress = {
        'city': 'Location unavailable',
        'state': 'Location unavailable',
        'area':
            'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}',
        'pincode': '000000',
      };
    }
  }

  // ============================================================================
  // SAVE/RESTORE LOCATION (SharedPreferences)
  // ============================================================================

  /// Save current location to local storage
  Future<void> _saveLocation() async {
    try {
      if (_currentPosition == null || _currentAddress == null) return;

      final prefs = await SharedPreferences.getInstance();

      await prefs.setDouble(_kLastLatitude, _currentPosition!.latitude);
      await prefs.setDouble(_kLastLongitude, _currentPosition!.longitude);
      await prefs.setString(_kLastAddress, jsonEncode(_currentAddress));
      await prefs.setString(_kLastTimestamp, DateTime.now().toIso8601String());

      Log.i('AutoLocation', '📍 [AutoLocation] Location saved');
    } catch (e) {
      Log.i('AutoLocation', '📍 [AutoLocation] Save error: $e');
    }
  }

  /// Load last saved location from local storage
  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final latitude = prefs.getDouble(_kLastLatitude);
      final longitude = prefs.getDouble(_kLastLongitude);
      final addressJson = prefs.getString(_kLastAddress);
      final timestamp = prefs.getString(_kLastTimestamp);

      if (latitude != null && longitude != null) {
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

        if (addressJson != null) {
          _currentAddress = Map<String, String>.from(jsonDecode(addressJson));
        }

        Log.i(
          'AutoLocation',
          '📍 [AutoLocation] Loaded saved location: $cityState',
        );
        if (timestamp != null) {
          Log.i('AutoLocation', '📍 [AutoLocation] Saved at: $timestamp');
        }

        notifyListeners();
      } else {
        Log.i('AutoLocation', '📍 [AutoLocation] No saved location found');
      }
    } catch (e) {
      Log.i('AutoLocation', '📍 [AutoLocation] Load error: $e');
    }
  }

  // ============================================================================
  // BACKGROUND REFRESH
  // ============================================================================

  /// Start automatic location refresh every 5 minutes
  void _startBackgroundRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      Log.i('AutoLocation', '📍 [AutoLocation] Background refresh triggered');
      await _detectGPSLocation();
    });
  }

  /// Manually refresh location
  Future<void> refreshLocation() async {
    Log.i('AutoLocation', '📍 [AutoLocation] Manual refresh requested');
    await _detectGPSLocation();
  }

  // ============================================================================
  // SET LOCATION FROM SAVED ADDRESS
  // ============================================================================

  /// Update current location to a saved address's coordinates and details.
  /// This is called when a user selects a saved address from the picker.
  void setLocationFromSavedAddress(Map<String, dynamic> address) {
    final lat = _coord(address, const ['lat', 'latitude']);
    final lng = _coord(address, const ['lng', 'longitude']);
    final fullAddr = address['fullAddress'] as String? ?? '';

    if (lat != null && lng != null) {
      _currentPosition = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    _currentAddress = {
      'city': address['city'] as String? ?? '',
      'state': address['state'] as String? ?? '',
      'area': address['area'] as String? ?? '',
      'pincode': address['pincode'] as String? ?? '',
      'fullAddress': fullAddr,
      'houseNo': address['houseNo'] as String? ?? '',
      'street': address['street'] as String? ?? '',
    };

    notifyListeners();
  }

  static double? _coord(Map<String, dynamic> address, List<String> keys) {
    for (final key in keys) {
      final value = address[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Check if location is available
  bool get hasLocation => _currentPosition != null && _currentAddress != null;

  /// Get distance between current position and target coordinates (in km)
  double? distanceTo(double targetLat, double targetLng) {
    if (_currentPosition == null) return null;

    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          targetLat,
          targetLng,
        ) /
        1000; // Convert to km
  }

  /// Clear saved location (use when user changes location manually)
  Future<void> clearSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastLatitude);
    await prefs.remove(_kLastLongitude);
    await prefs.remove(_kLastAddress);
    await prefs.remove(_kLastTimestamp);

    Log.i('AutoLocation', '📍 [AutoLocation] Saved location cleared');
  }

  /// Dispose service
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
