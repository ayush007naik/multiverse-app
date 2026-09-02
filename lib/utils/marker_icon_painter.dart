import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/logging_service.dart';

class MarkerIconPainter {
  static BitmapDescriptor? _shopCache;
  static BitmapDescriptor? _customerCache;
  static BitmapDescriptor? _riderBikeCache;
  static BitmapDescriptor? _riderCarCache;

  static Future<BitmapDescriptor> getShopMarker() async {
    if (_shopCache != null) return _shopCache!;
    _shopCache = await _loadAssetMarker('assets/icons/shop.png', 120);
    return _shopCache!;
  }

  static Future<BitmapDescriptor> getCustomerMarker() async {
    if (_customerCache != null) return _customerCache!;
    _customerCache = await _loadAssetMarker('assets/icons/home.png', 120);
    return _customerCache!;
  }

  static Future<BitmapDescriptor> getRiderMarker(String vehicleType) async {
    bool isFourWheeler = [
      'car',
      'jeep',
      'van',
      '4_wheeler',
    ].contains(vehicleType.toLowerCase());

    if (isFourWheeler) {
      if (_riderCarCache != null) return _riderCarCache!;
      _riderCarCache = await _loadAssetMarker('assets/icons/jeep.png', 130);
      return _riderCarCache!;
    } else {
      if (_riderBikeCache != null) return _riderBikeCache!;
      _riderBikeCache = await _loadAssetMarker('assets/icons/bike.png', 130);
      return _riderBikeCache!;
    }
  }

  static Future<BitmapDescriptor> _loadAssetMarker(
    String path,
    int width,
  ) async {
    try {
      ByteData data = await rootBundle.load(path);
      ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: width,
      );
      ui.FrameInfo fi = await codec.getNextFrame();
      final bytes = (await fi.image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      return BitmapDescriptor.bytes(bytes);
    } catch (e) {
      Log.e(
        'MarkerIconPainter',
        '❌ [MarkerIconPainter] Error loading asset $path: $e',
        ex: e,
      );
      // Fallback to default marker if asset loading fails
      return BitmapDescriptor.defaultMarker;
    }
  }
}
