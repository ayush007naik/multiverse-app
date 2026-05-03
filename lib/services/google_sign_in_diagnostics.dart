import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class GoogleSignInDiagnostics {
  static const String androidPackageName = 'com.ayush.multiverse.multiverses';
  static const String firebaseProjectId = 'multiverses-8d207';
  static const String debugSha1 =
      '3E:1C:18:37:92:0D:50:2F:F2:10:29:DC:A1:A1:67:02:53:34:5D:F3';

  static void logConfigSummary() {
    debugPrint(
      'Google Sign-In config => package: $androidPackageName, '
      'firebaseProject: $firebaseProjectId, debugSha1: $debugSha1',
    );
  }

  static String userMessageForError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('10') ||
        raw.contains('developer_error') ||
        raw.contains('http 400') ||
        raw.contains('status code: 400')) {
      return 'Google Sign-In configuration mismatch. Verify Firebase package, SHA-1, '
          'Google provider, and refresh google-services.json.';
    }

    if (raw.contains('network_error')) {
      return 'Network error during Google Sign-In. Check internet and try again.';
    }

    if (raw.contains('sign_in_canceled') || raw.contains('cancelled')) {
      return 'Google Sign-In was cancelled.';
    }

    return 'Google Sign-In failed. Check Firebase and Android OAuth configuration.';
  }

  static void logFailure(
    Object error,
    StackTrace stackTrace, {
    String source = 'google_sign_in',
  }) {
    debugPrint('[$source] Google Sign-In failed: $error');
    debugPrint('[$source] Stack trace: $stackTrace');
    logConfigSummary();

    if (error is PlatformException) {
      debugPrint(
        '[$source] PlatformException(code: ${error.code}, message: ${error.message}, details: ${error.details})',
      );
    }
  }
}
