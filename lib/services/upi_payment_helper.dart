import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class UPIPaymentHelper {
  static const List<String> _upiApps = [
    'com.google.android.apps.nbu.paisa.user', // Google Pay
    'com.phonepe.app', // PhonePe
    'net.one97.paytm', // Paytm
    'in.org.npci.upiapp', // BHIM
  ];

  static const Map<String, String> _appNames = {
    'com.google.android.apps.nbu.paisa.user': 'Google Pay',
    'com.phonepe.app': 'PhonePe',
    'net.one97.paytm': 'Paytm',
    'in.org.npci.upiapp': 'BHIM',
  };

  /// Check if any UPI app is installed
  static Future<bool> isUPIAvailable() async {
    for (String app in _upiApps) {
      Uri uri = Uri.parse('$app://');
      if (await canLaunchUrl(uri)) {
        return true;
      }
    }
    return false;
  }

  /// Get list of installed UPI apps
  static Future<List<String>> getInstalledUPIApps() async {
    List<String> installedApps = [];
    for (String app in _upiApps) {
      Uri uri = Uri.parse('$app://');
      if (await canLaunchUrl(uri)) {
        installedApps.add(app);
      }
    }
    return installedApps;
  }

  /// Open UPI payment via deeplink
  static Future<bool> payViaUPI({
    required String upiId,
    required String name,
    required String description,
    required double amount,
    String? transactionRef,
  }) async {
    try {
      // Create UPI intent URL
      String upiURL =
          'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(name)}'
          '&tn=${Uri.encodeComponent(description)}'
          '&am=$amount'
          '&cu=INR'
          '&tr=${transactionRef ?? DateTime.now().millisecondsSinceEpoch}';

      Uri uri = Uri.parse(upiURL);

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('No UPI app available');
      }
    } catch (e) {
      throw Exception('UPI payment failed: $e');
    }
  }

  /// Open specific UPI app
  static Future<bool> openSpecificUPIApp({
    required String appPackage,
    required String upiId,
    required String name,
    required String description,
    required double amount,
  }) async {
    try {
      String upiURL =
          'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(name)}'
          '&tn=${Uri.encodeComponent(description)}'
          '&am=$amount'
          '&cu=INR'
          '&tr=${DateTime.now().millisecondsSinceEpoch}';

      Uri uri = Uri.parse(upiURL);

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get app display name
  static String getAppName(String package) {
    return _appNames[package] ?? package;
  }
}
