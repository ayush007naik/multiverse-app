import 'package:flutter_test/flutter_test.dart';
import 'package:vendor_dashboard/services/product_image_search_service.dart';

void main() {
  group('ProductImageCandidate', () {
    test('prefers the hosted copy, then the thumbnail, then the source', () {
      const hosted = ProductImageCandidate(
        sourceUrl: 'https://provider.test/full.jpg',
        thumbnailUrl: 'https://provider.test/thumb.jpg',
        hostedUrl: 'https://ours.test/hosted.jpg',
      );
      expect(hosted.displayUrl, 'https://ours.test/hosted.jpg');

      const thumbnailOnly = ProductImageCandidate(
        sourceUrl: 'https://provider.test/full.jpg',
        thumbnailUrl: 'https://provider.test/thumb.jpg',
      );
      expect(thumbnailOnly.displayUrl, 'https://provider.test/thumb.jpg');

      const bare = ProductImageCandidate(sourceUrl: 'https://provider.test/full.jpg');
      expect(bare.displayUrl, 'https://provider.test/full.jpg');
    });

    test('an empty hosted url is ignored rather than returned blank', () {
      // A stored result can carry an empty string for a field the service could
      // not fill; returning it would put an empty string on the product.
      const candidate = ProductImageCandidate(
        sourceUrl: 'https://provider.test/full.jpg',
        hostedUrl: '',
        thumbnailUrl: 'https://provider.test/thumb.jpg',
      );
      expect(candidate.displayUrl, 'https://provider.test/thumb.jpg');
    });

    test('only a confident, brand-matching result counts as safe', () {
      const confident = ProductImageCandidate(
        sourceUrl: 'u',
        score: 0.6,
        brandMatch: true,
      );
      expect(confident.isConfident, isTrue);

      // Right score, wrong brand: a look-alike product.
      const lookAlike = ProductImageCandidate(
        sourceUrl: 'u',
        score: 0.9,
        brandMatch: false,
      );
      expect(lookAlike.isConfident, isFalse);

      // Exactly on the service's threshold counts as confident. This is 0.60,
      // mirroring MIN_ACCEPT_SCORE in the service's config.py; it was 0.55
      // until the bar was raised, and a mismatch here means the dashboard would
      // auto-attach something the service deliberately refused.
      const onThreshold = ProductImageCandidate(
        sourceUrl: 'u',
        score: 0.60,
        brandMatch: true,
      );
      expect(onThreshold.isConfident, isTrue);
      expect(
        const ProductImageCandidate(sourceUrl: 'u', score: 0.59).isConfident,
        isFalse,
      );
    });

    test('parses the service response, including null-valued fields', () {
      final candidate = ProductImageCandidate.fromJson(const {
        'full_url': 'https://provider.test/full.jpg',
        'thumbnail_url': 'https://provider.test/thumb.jpg',
        'hosted_url': null,
        'title': 'Amul Butter 500g',
        'source': 'openfoodfacts',
        'score': 0.77,
        'brand_match': true,
        'matched_by': 'similar',
        'requires_attribution': true,
        'attribution': 'Open Food Facts contributors · ODbL',
        'width': '400',
        'height': null,
      });

      expect(candidate.sourceUrl, 'https://provider.test/full.jpg');
      expect(candidate.hostedUrl, isNull);
      expect(candidate.title, 'Amul Butter 500g');
      expect(candidate.source, 'openfoodfacts');
      expect(candidate.score, 0.77);
      expect(candidate.isConfident, isTrue);
      expect(candidate.requiresAttribution, isTrue);
      expect(candidate.width, 400);
      expect(candidate.height, isNull);
    });

    test('brand_match defaults to true when the service omits it', () {
      // An absent flag is not a negative signal; treating it as a mismatch
      // would silently reject every result from an older service build.
      final candidate = ProductImageCandidate.fromJson(const {
        'full_url': 'https://provider.test/full.jpg',
        'thumbnail_url': 'https://provider.test/full.jpg',
        'source': 'wikimedia',
      });
      expect(candidate.brandMatch, isTrue);
    });

    test('falls back through label sources for the grid tile', () {
      expect(
        const ProductImageCandidate(sourceUrl: 'u', title: 'Amul Butter').label,
        'Amul Butter',
      );
      expect(
        const ProductImageCandidate(
          sourceUrl: 'u',
          sourcePage: 'https://commons.test/File:Amul.jpg',
        ).label,
        'https://commons.test/File:Amul.jpg',
      );
      expect(const ProductImageCandidate(sourceUrl: 'u', source: 'pexels').label, 'pexels');
    });
  });

  group('ProductImageSelection', () {
    test('names the source in a way a vendor can read', () {
      expect(
        const ProductImageSelection(
          url: 'https://x/1.jpg',
          title: 'Amul Butter 500g',
          source: 'openfoodfacts',
        ).caption,
        'Amul Butter 500g · Open Food Facts',
      );
      expect(
        const ProductImageSelection(url: 'https://x/1.jpg', source: 'serpapi').caption,
        'Google Images',
      );
      expect(
        const ProductImageSelection(url: 'https://x/1.jpg', source: 'cache').caption,
        'saved earlier',
      );
    });

    test('falls back to the source alone when the result has no title', () {
      expect(
        const ProductImageSelection(url: 'https://x/1.jpg', source: 'pexels').caption,
        'Pexels',
      );
      // An unrecognised source is shown as-is rather than blanked out.
      expect(
        const ProductImageSelection(url: 'https://x/1.jpg', source: 'some_new_api')
            .caption,
        'some_new_api',
      );
    });

    test('carries the chosen url and provenance through from a candidate', () {
      const candidate = ProductImageCandidate(
        sourceUrl: 'https://provider.test/full.jpg',
        hostedUrl: 'https://ours.test/hosted.jpg',
        title: 'Tata Salt',
        source: 'openfoodfacts',
        score: 0.9,
        requiresAttribution: true,
        attribution: 'Open Food Facts contributors · ODbL',
      );
      final selection = ProductImageSelection.fromCandidate(
        candidate,
        isBestMatch: true,
      );

      // The product is given the hosted copy, not the provider's URL.
      expect(selection.url, 'https://ours.test/hosted.jpg');
      expect(selection.isBestMatch, isTrue);
      expect(selection.requiresAttribution, isTrue);
      expect(selection.attribution, 'Open Food Facts contributors · ODbL');
    });
  });
}
