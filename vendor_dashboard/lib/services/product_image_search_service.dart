import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One image the service found on the internet, already ranked.
class ProductImageCandidate {
  /// The provider's own file. Kept for reference, rarely displayed.
  final String sourceUrl;

  /// Where the service re-hosted the image. Preferred for the product because
  /// it belongs to us and will not disappear when a provider reorganises.
  final String? hostedUrl;

  final String? thumbnailUrl;
  final String title;

  /// 'serpapi' | 'google_cse' | 'pexels' | 'unsplash' | 'wikimedia' |
  /// 'openverse' | 'cache'
  final String source;

  final String? sourcePage;
  final String? license;

  /// Creator and license, e.g. "Jane Doe · CC BY-SA 4.0". Appended to the
  /// product description when the license requires credit.
  final String? attribution;
  final bool requiresAttribution;

  final int? width;
  final int? height;

  /// 0-1 relevance. The service only returns candidates above zero; the
  /// auto-attach threshold is enforced server-side.
  final double score;

  /// True when the product's brand appears in the image's own title.
  final bool brandMatch;

  /// 'exact' | 'similar' | 'relaxed' | 'barcode' | 'cache' | null
  final String? matchedBy;

  const ProductImageCandidate({
    required this.sourceUrl,
    this.hostedUrl,
    this.thumbnailUrl,
    this.title = '',
    this.source = '',
    this.sourcePage,
    this.license,
    this.attribution,
    this.requiresAttribution = false,
    this.width,
    this.height,
    this.score = 0,
    this.brandMatch = true,
    this.matchedBy,
  });

  /// The URL to put on the product.
  ///
  /// Prefers the hosted copy; falls back to the provider thumbnail so a result
  /// is always displayable even when storage is unavailable.
  String get displayUrl {
    if (hostedUrl != null && hostedUrl!.isNotEmpty) return hostedUrl!;
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl!;
    return sourceUrl;
  }

  /// Whether the image is safe to save straight onto a product without the
  /// vendor looking at it. Mirrors the service's own threshold.
  ///
  /// Below this the image is left blank rather than guessed at. A product
  /// with no photo is recoverable; a product with the wrong photo ships to
  /// customers.
  bool get isConfident => score >= 0.60 && brandMatch;

  bool get isExact => matchedBy == 'exact' || matchedBy == 'barcode';

  /// A short human label for the result tile.
  String get label {
    if (title.trim().isNotEmpty) return title.trim();
    if (sourcePage != null && sourcePage!.isNotEmpty) return sourcePage!;
    return source;
  }

  factory ProductImageCandidate.fromJson(Map<String, dynamic> json) {
    return ProductImageCandidate(
      sourceUrl: (json['full_url'] ?? '').toString(),
      hostedUrl: _optString(json['hosted_url']),
      thumbnailUrl: _optString(json['thumbnail_url']),
      title: (json['title'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      sourcePage: _optString(json['source_page']),
      license: _optString(json['license']),
      attribution: _optString(json['attribution']),
      requiresAttribution: json['requires_attribution'] == true,
      width: _optInt(json['width']),
      height: _optInt(json['height']),
      score: _optDouble(json['score']),
      brandMatch: json['brand_match'] != false,
      matchedBy: _optString(json['matched_by']),
    );
  }

  static String? _optString(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static int? _optInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static double _optDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// Result of a lookup, including whether anything good enough was found.
class ProductImageSearchResult {
  final List<ProductImageCandidate> candidates;

  /// The service's own pick, or null when nothing cleared the threshold.
  final ProductImageCandidate? best;

  final bool found;
  final int durationMs;
  final String query;

  const ProductImageSearchResult({
    this.candidates = const [],
    this.best,
    this.found = false,
    this.durationMs = 0,
    this.query = '',
  });
}

/// Raised when the image service cannot be reached, so the UI can explain what
/// to do instead of showing a raw network error.
class ImageSearchUnavailable implements Exception {
  final String message;
  const ImageSearchUnavailable(this.message);
  @override
  String toString() => message;
}

/// The image the vendor settled on, and where it came from.
///
/// Returned by the picker instead of a bare URL so the form can label the
/// image it attached on the vendor's behalf ("best match, Open Food Facts")
/// rather than showing an anonymous thumbnail.
class ProductImageSelection {
  /// The URL to store on the product.
  final String url;

  /// What the result was called by whoever published the photo. Shown under
  /// the thumbnail so the vendor can sanity-check it is the right item.
  final String title;

  final String source;

  final String? sourcePage;
  final String? license;
  final String? attribution;

  /// True when the licence obliges us to credit the author.
  final bool requiresAttribution;

  final double score;

  /// True when this was the service's own pick rather than a manual choice.
  final bool isBestMatch;

  const ProductImageSelection({
    required this.url,
    this.title = '',
    this.source = '',
    this.sourcePage,
    this.license,
    this.attribution,
    this.requiresAttribution = false,
    this.score = 0,
    this.isBestMatch = false,
  });

  factory ProductImageSelection.fromCandidate(
    ProductImageCandidate candidate, {
    bool isBestMatch = false,
  }) {
    return ProductImageSelection(
      url: candidate.displayUrl,
      title: candidate.title,
      source: candidate.source,
      sourcePage: candidate.sourcePage,
      license: candidate.license,
      attribution: candidate.attribution,
      requiresAttribution: candidate.requiresAttribution,
      score: candidate.score,
      isBestMatch: isBestMatch,
    );
  }

  /// A short line for the product form: what the photo is and where it is from.
  String get caption {
    final where = switch (source) {
      'openfoodfacts' => 'Open Food Facts',
      'serpapi' => 'Google Images',
      'google_cse' => 'Google Images',
      'pexels' => 'Pexels',
      'unsplash' => 'Unsplash',
      'wikimedia' => 'Wikimedia',
      'openverse' => 'Openverse',
      'cache' => 'saved earlier',
      _ => source,
    };
    return title.trim().isNotEmpty ? '$title · $where' : where;
  }
}

/// Why a photo lookup came back without a photo.
enum ImageLookupFailure {
  /// The service answered and had nothing good enough. Not an error.
  none,

  /// The service rejected this session (401/403). Signing in again fixes it.
  unauthorized,

  /// The service could not be reached, timed out, or answered 5xx.
  unreachable,

  /// Anything else, including a malformed response.
  error,
}

/// A photo lookup that reports *why* it came back empty.
///
/// `findExactImage` answers null for both "the service had nothing good enough"
/// and "the request failed", which is the same thing to the spreadsheet
/// importer: products imported, no photos, no explanation. A vendor who turned
/// photo lookup on has no way to tell a product with no photo on the internet
/// from a rejected session or a dead endpoint.
class ImageLookupOutcome {
  /// The photo to attach, or null when there is none to attach.
  final String? url;
  final ImageLookupFailure reason;

  /// True when the lookup itself failed, as opposed to finding nothing.
  bool get failed => reason != ImageLookupFailure.none;

  const ImageLookupOutcome(this.url, this.reason);

  const ImageLookupOutcome.found(String url)
    : this(url, ImageLookupFailure.none);
  const ImageLookupOutcome.notFound() : this(null, ImageLookupFailure.none);
}

/// Talks to the Python image search service (`image_search_service/`).
///
/// The service finds candidate photos on the internet, verifies them by
/// downloading and re-encoding, and re-hosts them in Supabase Storage so the
/// product ends up with a URL that belongs to us.
///
/// The endpoint is compiled in, so a plain `flutter build apk --release` works
/// with no extra flags. Override it per build when testing a change:
///   flutter run --dart-define=IMAGE_SEARCH_URL=http://localhost:8000
class ProductImageSearchService {
  ProductImageSearchService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// The production endpoint, compiled in.
  ///
  /// This used to be empty by default, so a release build carried no endpoint
  /// and the importer told the vendor to rebuild with a --dart-define. That is
  /// a flag someone has to remember forever: a release made by `flutter build
  /// apk --release`, by CI, or by anyone not knowing the rule imports every
  /// product with no photo and no obvious reason why. Baking the deployed
  /// Cloud Run URL in means the default is the working one.
  ///
  /// Cloud Run domain mapping, not the `<hash>-<region>.a.run.app` host, so a
  /// redeploy does not invalidate this. Kept in step with
  /// `image_search_config.json` by `deploy_cloudrun.sh`.
  static const String _defaultUrl =
      'https://multiverse-image-search-89114358837.asia-south1.run.app';

  static const String _configuredUrl = String.fromEnvironment(
    'IMAGE_SEARCH_URL',
  );
  static const String _devFallback = 'http://localhost:8000';

  /// An explicit --dart-define wins, then localhost for a developer running the
  /// Python service, then the compiled-in production endpoint. The order
  /// matters: a debug build must not quietly talk to production, and a release
  /// build must never try localhost.
  static String get baseUrl {
    if (_configuredUrl.isNotEmpty) return _configuredUrl;
    return kDebugMode ? _devFallback : _defaultUrl;
  }

  /// True whenever there is an endpoint to call. Always true now, which is the
  /// point: the importer no longer has a "this build has no image service"
  /// state to fall into.
  static bool get isConfigured => baseUrl.isNotEmpty;

  static const Duration _searchTimeout = Duration(seconds: 30);
  static const Duration _resolveTimeout = Duration(seconds: 45);

  void dispose() => _client.close();

  /// Ranked grid of photos for a product, for the vendor to pick from.
  Future<ProductImageSearchResult> search({
    required String name,
    String brand = '',
    String variant = '',
    String category = '',
    String subcategory = '',
    String description = '',
    String barcode = '',
    int limit = 18,

    /// Downloads and re-hosts the top [hostTop] results so the best matches
    /// are already ours when the vendor taps one.
    int hostTop = 4,
    String? folder,
  }) async {
    final body = await _post('/search', {
      'product': _productPayload(
        name: name,
        brand: brand,
        variant: variant,
        category: category,
        subcategory: subcategory,
        description: description,
        barcode: barcode,
      ),
      'limit': limit,
      'host_top': hostTop,
      if (folder != null && folder.isNotEmpty) 'folder': folder,
    }, _searchTimeout);
    return _parseResult(body);
  }

/// A photo lookup that reports *why* it came back empty.
  ///
  /// `findExactImage` answers null for both "the service had nothing good
  /// enough" and "the request failed", which is the same thing to the
  /// spreadsheet importer: products imported, no photos, no explanation. A
  /// vendor who turned photo lookup on has no way to tell a product with no
  /// photo on the internet from a rejected session or a dead endpoint.
  ///
  /// Never throws. A failed lookup must never fail an otherwise good import.
  Future<ImageLookupOutcome> lookupImage({
    required String name,
    String brand = '',
    String variant = '',
    String category = '',
    String subcategory = '',
    String description = '',
    String barcode = '',
    String? folder,
    Duration timeout = _resolveTimeout,
  }) async {
    try {
      final body = await _post('/resolve', {
        'product': _productPayload(
          name: name,
          brand: brand,
          variant: variant,
          category: category,
          subcategory: subcategory,
          description: description,
          barcode: barcode,
        ),
        if (folder != null && folder.isNotEmpty) 'folder': folder,
        'verify_candidates': 3,
      }, timeout);
      final bestMap = _mapOrNull(body['best']);
      if (bestMap == null) return const ImageLookupOutcome.notFound();
      final best = ProductImageCandidate.fromJson(bestMap);
      return best.displayUrl.isEmpty
          ? const ImageLookupOutcome.notFound()
          : ImageLookupOutcome.found(best.displayUrl);
    } on ImageSearchUnavailable catch (e) {
      // The message is written for a human, and _post distinguishes the causes
      // by what it says, so it is read here rather than duplicating the
      // classification. Matching on wording is fragile in principle, but these
      // are two strings in one file.
      final text = e.message.toLowerCase();
      if (text.contains('expired')) {
        // The vendor's own sign-in went stale. Re-authenticating fixes it.
        return const ImageLookupOutcome(null, ImageLookupFailure.unauthorized);
      }
      if (text.contains('could not verify') || text.contains('unexpected response')) {
        // The service answered, but either rejected a token it should have been
        // able to verify or sent back something this client cannot read -- a
        // project-id mismatch, a deploy mid-rollout, a proxy error page. Nothing
        // the vendor can fix, and not their session either, so it is reported as
        // a server fault rather than sent to sign in again.
        return const ImageLookupOutcome(null, ImageLookupFailure.error);
      }
      return const ImageLookupOutcome(null, ImageLookupFailure.unreachable);
    } on TimeoutException {
      return const ImageLookupOutcome(null, ImageLookupFailure.unreachable);
    } on http.ClientException {
      return const ImageLookupOutcome(null, ImageLookupFailure.unreachable);
    } on FormatException {
      return const ImageLookupOutcome(null, ImageLookupFailure.error);
    }
  }

  /// The single best photo, or null when the service is not confident.
  ///
  /// Used by the spreadsheet importer, which must not attach a guess. Failures
  /// are swallowed and reported as "no image" so a flaky image service can
  /// never fail an otherwise good import. Prefer [lookupImage] when the caller
  /// can show the vendor why nothing was found.
  Future<ProductImageCandidate?> findExactImage({
    required String name,
    String brand = '',
    String variant = '',
    String category = '',
    String subcategory = '',
    String description = '',
    String barcode = '',
    String? folder,
    Duration timeout = _resolveTimeout,
  }) async {
    try {
      final body = await _post('/resolve', {
        'product': _productPayload(
          name: name,
          brand: brand,
          variant: variant,
          category: category,
          subcategory: subcategory,
          description: description,
          barcode: barcode,
        ),
        if (folder != null && folder.isNotEmpty) 'folder': folder,
        'verify_candidates': 3,
      }, timeout);
      final bestMap = _mapOrNull(body['best']);
      if (bestMap == null) return null;
      final best = ProductImageCandidate.fromJson(bestMap);
      return best.displayUrl.isEmpty ? null : best;
    } on TimeoutException {
      return null;
    } on ImageSearchUnavailable {
      return null;
    } on http.ClientException {
      return null;
    }
  }

  /// Re-hosts a specific image the vendor picked from the grid.
  Future<String?> hostImage(String imageUrl, {String? folder}) async {
    try {
      final body = await _post('/host', {
        'full_url': imageUrl,
        if (folder != null && folder.isNotEmpty) 'folder': folder,
      }, _searchTimeout);
      return body['hosted_url']?.toString();
    } on Exception {
      // Not fatal: the provider URL still displays and still saves.
      return null;
    }
  }

  /// Liveness probe, used to explain a failure in plain language.
  Future<bool> isReachable() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 6));
      return response.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  static Map<String, dynamic> _productPayload({
    required String name,
    required String brand,
    required String variant,
    required String category,
    required String subcategory,
    required String description,
    required String barcode,
  }) {
    return {
      'name': name,
      'brand': brand,
      'variant': variant,
      'category': category,
      'subcategory': subcategory,
      // Long descriptions drown the query; the first line carries the gist.
      'description': description.length > 300
          ? description.substring(0, 300)
          : description,
      'barcode': barcode,
    };
  }

  static ProductImageSearchResult _parseResult(Map<String, dynamic> body) {
    final raw = body['candidates'];
    final candidates = <ProductImageCandidate>[];
    if (raw is List) {
      for (final item in raw) {
        final map = _mapOrNull(item);
        if (map == null) continue;
        final candidate = ProductImageCandidate.fromJson(map);
        if (candidate.displayUrl.isEmpty) continue;
        candidates.add(candidate);
      }
    }
    final best = _mapOrNull(body['best']);
    return ProductImageSearchResult(
      candidates: candidates,
      best: best == null ? null : ProductImageCandidate.fromJson(best),
      found: body['found'] == true,
      durationMs: (body['duration_ms'] as num?)?.toInt() ?? 0,
      query: (body['query'] ?? '').toString(),
    );
  }

  static Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// Sends an authenticated JSON request.
  ///
  /// A Firebase Auth ID token is attached the same way the rest of this app
  /// talks to its backend, so the service can tell vendors apart and reject
  /// anonymous traffic in production.
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
    Duration timeout,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _client
          .post(uri, headers: await _headers(), body: jsonEncode(payload))
          .timeout(timeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        // The service distinguishes an expired token from one it cannot verify at
        // all, and the two need different answers from the vendor: one is fixed
        // by signing in again, the other is a server-side config problem they
        // cannot fix and should not be sent to re-authenticate for. Both were
        // previously reported as "sign out and back in", which sent us looking
        // at the vendor's session when the token was never the problem.
        final detail = _errorFrom(response).toLowerCase();
        if (detail.contains('expired')) {
          throw const ImageSearchUnavailable(
            'This session has expired. Sign out and sign in again.',
          );
        }
        throw const ImageSearchUnavailable(
          'The image service could not verify this sign-in.',
        );
      }
      if (response.statusCode >= 500) {
        throw const ImageSearchUnavailable(
          'The image service is having trouble. Try again in a moment.',
        );
      }
      if (response.statusCode >= 400) {
        throw ImageSearchUnavailable(_errorFrom(response));
      }
      return _mapOrNull(jsonDecode(response.body)) ?? const {};
    } on TimeoutException {
      throw const ImageSearchUnavailable(
        'The image service did not respond in time. It may still be starting up.',
      );
    } on ImageSearchUnavailable {
      rethrow;
    } on http.ClientException catch (e) {
      throw ImageSearchUnavailable(
        'Could not reach the image service at $baseUrl. ${e.message}',
      );
    } on FormatException {
      throw const ImageSearchUnavailable(
        'The image service returned an unexpected response.',
      );
    }
  }

  static String _errorFrom(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        return body['detail'].toString();
      }
    } on FormatException {
      // Fall through to the generic message.
    }
    return 'Image search failed (HTTP ${response.statusCode}).';
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } on Exception {
      // Signed out, or Firebase unavailable: the service decides whether to
      // allow the anonymous call.
    }
    return headers;
  }
}
