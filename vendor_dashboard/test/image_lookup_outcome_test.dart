import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendor_dashboard/services/product_image_search_service.dart';

/// The reported reason is the whole point of `lookupImage`: the spreadsheet
/// importer used to collapse "no photo exists" and "the request failed" into
/// one silent null, so a vendor whose session was rejected saw a clean import
/// with no images and nothing to act on.
void main() {
  ProductImageSearchService serviceReturning(
    int status,
    String body, {
    bool throwError = false,
  }) {
    return ProductImageSearchService(
      client: MockClient((_) async {
        if (throwError) throw http.ClientException('connection refused');
        return http.Response(body, status,
            headers: {'content-type': 'application/json'});
      }),
    );
  }

  test('a found photo reports no failure', () async {
    final svc = serviceReturning(
      200,
      jsonEncode({
        'best': {'full_url': 'https://ours.test/a.jpg', 'score': 0.9},
      }),
    );
    final out = await svc.lookupImage(name: 'Amul Butter');
    expect(out.url, 'https://ours.test/a.jpg');
    expect(out.reason, ImageLookupFailure.none);
    expect(out.failed, isFalse);
  });

  test('a 200 with no best is a miss, not a failure', () async {
    // This is the normal case for a product nobody has photographed. It must
    // not be reported as an error, or every honest miss looks like an outage.
    final svc = serviceReturning(200, jsonEncode({'best': null, 'found': false}));
    final out = await svc.lookupImage(name: 'Some Obscure Product');
    expect(out.url, isNull);
    expect(out.reason, ImageLookupFailure.none);
    expect(out.failed, isFalse);
  });

  // An expired token is the vendor's own stale sign-in, and re-authenticating
  // fixes it. The service says "token expired" for exactly this case.
  test('401 for an expired token is reported as an unauthorized session',
      () async {
    final svc = serviceReturning(401, jsonEncode({'detail': 'token expired'}));
    final out = await svc.lookupImage(name: 'Amul Butter');
    expect(out.url, isNull);
    expect(out.reason, ImageLookupFailure.unauthorized);
    expect(out.failed, isTrue);
  });

  // Any other 401 means the service could not verify a token that should have
  // been fine -- a project-id mismatch, a signature check that failed. Telling
  // the vendor to sign in again would send them down the wrong path, so this is
  // a server fault instead.
  test('401 for an unverifiable token is a service fault, not a bad session',
      () async {
    final svc = serviceReturning(401, jsonEncode({'detail': 'invalid token'}));
    final out = await svc.lookupImage(name: 'Amul Butter');
    expect(out.reason, ImageLookupFailure.error);
    expect(out.failed, isTrue);
  });

  test('403 is a service fault, not a bad session', () async {
    final svc = serviceReturning(403, jsonEncode({'detail': 'forbidden'}));
    expect((await svc.lookupImage(name: 'X')).reason,
        ImageLookupFailure.error);
  });

  test('5xx is reported as unreachable', () async {
    final svc = serviceReturning(503, jsonEncode({'detail': 'unavailable'}));
    expect((await svc.lookupImage(name: 'X')).reason,
        ImageLookupFailure.unreachable);
  });

  test('a transport error is reported as unreachable', () async {
    final svc = serviceReturning(0, '', throwError: true);
    expect((await svc.lookupImage(name: 'X')).reason,
        ImageLookupFailure.unreachable);
  });

  test('a malformed body is an error, not an unreachable service', () async {
    final svc = serviceReturning(200, 'not json at all');
    final out = await svc.lookupImage(name: 'X');
    expect(out.reason, ImageLookupFailure.error);
    expect(out.url, isNull);
  });

  test('never throws, so an image failure cannot fail an import', () async {
    final svc = serviceReturning(500, jsonEncode({'detail': 'boom'}));
    // The property the importer depends on: it awaits this inside a loop and
    // has no try/catch of its own.
    expect(() => svc.lookupImage(name: 'X'), returnsNormally);
  });
}
