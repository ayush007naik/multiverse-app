import '../core/app_config.dart';

class EnvironmentConfig {
  EnvironmentConfig._();

  /// Razorpay publishable key.
  ///
  /// Pass it at build time with
  /// `--dart-define=RAZORPAY_KEY=<key_id>` (e.g. `rzp_test_...` for test mode,
  /// `rzp_live_...` for production) to override the baked-in default below.
  ///
  /// The Razorpay key ID is a PUBLISHABLE key — Razorpay distributes it inside
  /// client SDKs by design, so embedding it as a default is safe. The secret
  /// (`RAZORPAY_KEY_SECRET`) lives only on the server/Secret Manager and must
  /// never be baked in. The admin dashboard's runtime key stream
  /// (`RuntimeApiKeys`, backed by `app_config/razorpay`) overrides this at
  /// runtime, so builds run without `--dart-define-from-file=config.json`.
  static const String razorpayKey = String.fromEnvironment(
    'RAZORPAY_KEY',
    defaultValue: 'rzp_live_TKr1pRtbWrw45v',
  );

  static bool get isProduction => AppConfig.isProduction;

  static String get razorpayKeyOrThrow {
    const key = razorpayKey;
    if (key.isEmpty) {
      throw StateError(
        'RAZORPAY_KEY not set. Run with --dart-define=RAZORPAY_KEY=your_key',
      );
    }
    return key;
  }
}
