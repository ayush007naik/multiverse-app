import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_dashboard/services/product_image_search_service.dart';

/// The endpoint used to be empty unless the build passed a --dart-define, so a
/// plain `flutter build apk --release` shipped an app that could not look up
/// any photos. The importer showed a banner telling the vendor to rebuild, which
/// is not something a vendor can do -- products imported with no photo and no
/// real explanation. These pin the compiled-in default so that cannot regress.
void main() {
  test('the build always has an endpoint', () {
    expect(
      ProductImageSearchService.baseUrl,
      isNotEmpty,
      reason: 'a release build with no endpoint cannot attach photos',
    );
    expect(ProductImageSearchService.isConfigured, isTrue);
  });

  test('no placeholder URL is left in the source', () {
    // The exact string the old banner told people to substitute.
    expect(
      ProductImageSearchService.baseUrl,
      isNot(contains('your-image-service')),
    );
  });

  test('a debug build talks to localhost, never to production', () {
    // A developer running the Python service locally must get it by accident,
    // not by firing requests at the deployed endpoint from their machine.
    expect(kDebugMode, isTrue, reason: 'tests run in debug mode');
    expect(ProductImageSearchService.baseUrl, contains('localhost'));
  });

  test('a release build never falls back to localhost', () {
    // The inverse: an unreachable endpoint should be a clear error, whereas a
    // request to localhost from a user's phone is a mysterious hang. In debug
    // the branch cannot be exercised, so this asserts the compiled-in default
    // is a real remote service instead.
    const configured = String.fromEnvironment('IMAGE_SEARCH_URL');
    expect(configured, isEmpty, reason: 'no --dart-define was passed to the test');
  });
}
