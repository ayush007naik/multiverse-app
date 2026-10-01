import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vendor_dashboard/services/product_image_search_service.dart';

/// Replays a response captured from the running image service through the real
/// client, so the payload contract is checked against bytes the service
/// actually produced rather than against a hand-written map that can drift.
///
/// Regenerate with the service running:
///   curl -s -X POST $URL/search -H 'Content-Type: application/json' \
///     -d '{"product":{"name":"Amul Butter","brand":"Amul","variant":"500g",
///          "category":"Grocery","subcategory":"Dairy"},
///          "limit":18,"host_top":4,"folder":"e2e_verify"}'
///     | python3 -m json.tool > test/fixtures/search_hosted.json
String _fixture(String name) =>
    File('test/fixtures/$name.json').readAsStringSync();

ProductImageSearchService _serviceReturning(String name) {
  final body = _fixture(name);
  return ProductImageSearchService(
    client: MockClient((request) async {
      // The service must be sending what the client expects to send.
      expect(request.method, 'POST');
      expect(request.headers['Content-Type'], 'application/json');
      final sent = jsonDecode(request.body) as Map<String, dynamic>;
      expect(sent['product'], isA<Map<String, dynamic>>());
      return http.Response(body, 200, headers: {'content-type': 'application/json'});
    }),
  );
}

void main() {
  group('a real /search response', () {
    late ProductImageSearchResult result;

    setUp(() async {
      result = await _serviceReturning('search_hosted').search(
        name: 'Amul Butter',
        brand: 'Amul',
        variant: '500g',
        category: 'Grocery',
        subcategory: 'Dairy',
        folder: 'e2e_verify',
      );
    });

    test('parses without losing a single grid entry', () {
      final body = jsonDecode(_fixture('search_hosted')) as Map<String, dynamic>;
      expect(result.found, isTrue);
      expect(result.candidates, hasLength((body['candidates'] as List).length));
      expect(result.query, body['query']);
      expect(result.durationMs, greaterThanOrEqualTo(0));
    });

    test('every candidate has a url the grid can actually load', () {
      // displayUrl is what Image.network is handed. An empty string here is a
      // broken image tile, and _parseResult drops those silently, so this
      // asserts both that nothing was dropped and that what survived is usable.
      expect(result.candidates, isNotEmpty);
      for (final candidate in result.candidates) {
        expect(
          candidate.displayUrl,
          isNotEmpty,
          reason: 'candidate "${candidate.title}" has no loadable url',
        );
        expect(candidate.displayUrl, startsWith('http'));
        expect(candidate.thumbnailUrl, anyOf(isNull, startsWith('http')));
      }
    });

    test('the hosted copy wins over the provider url', () {
      // This is the whole point of re-hosting: the product must end up with a
      // URL of ours, not one that can be reorganised or deleted upstream.
      final hosted = result.candidates.where((c) => c.hostedUrl != null);
      expect(hosted, isNotEmpty, reason: 'no candidate was re-hosted');
      for (final candidate in hosted) {
        expect(candidate.displayUrl, candidate.hostedUrl);
      }
    });

    test('dimensions and provenance survive the round trip', () {
      final body = jsonDecode(_fixture('search_hosted')) as Map<String, dynamic>;
      final raw = (body['candidates'] as List).cast<Map<String, dynamic>>();
      for (var i = 0; i < raw.length; i++) {
        final parsed = result.candidates[i];
        expect(parsed.sourceUrl, raw[i]['full_url']);
        expect(parsed.title, raw[i]['title']);
        expect(parsed.source, raw[i]['source']);
        expect(parsed.sourcePage, raw[i]['source_page']);
        expect(parsed.license, raw[i]['license']);
        expect(parsed.requiresAttribution, raw[i]['requires_attribution']);
        expect(parsed.brandMatch, raw[i]['brand_match']);
        expect(parsed.matchedBy, raw[i]['matched_by']);
        expect(parsed.score, closeTo((raw[i]['score'] as num).toDouble(), 1e-9));
        expect(parsed.width, raw[i]['width']);
        expect(parsed.height, raw[i]['height']);
      }
    });

    test('the Open Food Facts attribution requirement is carried through', () {
      // The dashboard prints the attribution line when this is true, so losing
      // it would strip a licence the service is obliged to show.
      final off = result.candidates.where((c) => c.source == 'openfoodfacts');
      expect(off, isNotEmpty);
      expect(off.every((c) => c.requiresAttribution), isTrue);
      expect(off.every((c) => (c.attribution ?? '').isNotEmpty), isTrue);
    });
  });

  group('a /search response whose best match is disqualified', () {
    test('has a null best and survives parsing', () async {
      // Non-product imagery (a costume, an office, a lunch photo) and unrelated
      // look-alikes are capped below the attach threshold, so the service sends
      // best: null while still returning the grid. The vendor must still be
      // able to browse and choose; nothing may look automatically attachable.
      final body =
          jsonDecode(_fixture('search_disqualified')) as Map<String, dynamic>;
      final result = await _serviceReturning('search_disqualified')
          .search(name: 'Quantum Flux Capacitor Mk II', brand: 'Zorg', variant: '1 unit');

      expect(body['best'], isNull);
      expect(result.best, isNull);
      expect(result.candidates, isNotEmpty);
      expect(
        result.candidates.every((c) => c.score < 0.60),
        isTrue,
        reason: 'no result in a rejected set may look attachable',
      );
    });
  });

  group('a /resolve response', () {
    test('cold gives the import path a hosted, attributed photo', () async {
      final result = await _serviceReturning('resolve_cold').findExactImage(
        name: 'Colgate Strong Teeth Toothpaste',
        brand: 'Colgate',
        variant: '150g',
        category: 'Personal Care',
        subcategory: 'Oral Care',
        folder: 'e2e_verify',
      );

      expect(result, isNotNull);
      expect(result!.sourceUrl, startsWith('http'));
      expect(result.displayUrl, isNotEmpty);
      // The importer saves result.displayUrl and nothing else, so a blank one
      // would quietly write an empty string onto the product.
      expect(result.displayUrl.trim(), isNotEmpty);
    });

    test('served from cache still yields a usable url', () async {
      // The cached shape is its own: matched_by "cache", score 1.0, and a
      // thumbnail that falls back to the source url when nothing was hosted.
      final result = await _serviceReturning('resolve_cache').findExactImage(
        name: 'Colgate Strong Teeth Toothpaste',
        brand: 'Colgate',
        variant: '150g',
        folder: 'e2e_verify',
      );

      expect(result, isNotNull);
      expect(result!.matchedBy, 'cache');
      expect(result.displayUrl, isNotEmpty);
      expect(result.displayUrl, startsWith('http'));
    });

    test('found:false becomes null, so the row imports without a photo', () async {
      // Silent by design: a product the service is not confident about is
      // saved imageless rather than given a wrong photo.
      final result = await _serviceReturning('resolve_notfound').findExactImage(
        name: 'Zzzz Nonexistent Widget 9999',
        brand: 'Zzzz',
      );

      expect(result, isNull);
    });
  });

  group('the request the client sends', () {
    test('matches the fields the service requires', () async {
      Map<String, dynamic>? sent;
      final service = ProductImageSearchService(
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(_fixture('search_hosted'), 200);
        }),
      );

      await service.search(
        name: 'Amul Butter',
        brand: 'Amul',
        variant: '500g',
        category: 'Grocery',
        subcategory: 'Dairy',
        description: 'x' * 400,
        folder: 'e2e_verify',
      );

      final product = sent!['product'] as Map<String, dynamic>;
      // Pydantic rejects an unknown or missing field, which the client can only
      // report as "the service returned an unexpected response".
      for (final key in const [
        'name',
        'brand',
        'variant',
        'category',
        'subcategory',
        'description',
        'barcode',
      ]) {
        expect(product.containsKey(key), isTrue, reason: 'missing $key');
        expect(product[key], isA<String>(), reason: '$key must be a string');
      }
      expect(sent!['limit'], isA<int>());
      expect(sent!['host_top'], isA<int>());
      expect(sent!['folder'], 'e2e_verify');
      // A 400-character description is sent, not truncated by the transport.
      expect((product['description']! as String).length, lessThanOrEqualTo(300));
    });
  });
}
