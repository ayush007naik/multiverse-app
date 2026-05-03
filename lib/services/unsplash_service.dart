import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:developer' as developer;

class UnsplashService {
  static const String _accessKey = 'A2P0wDjagFn_fmi1TfHpu2CyS0EbAmXcppaIIWlASOQ';
  static const String _baseUrl = 'https://api.unsplash.com';
  static const String _searchPath = '/search/photos';
  
  // Local cache to avoid repeated API calls during same session
  static final Map<String, String> _cache = {};

  static Future<bool> _hasInternet() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) return false;
      
      // Secondary check: try to lookup a reliable host
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Cache for multiple images per category to avoid repetition
  static final Map<String, List<String>> _categoryImagesCache = {};

  /// Get random image from category with unique search queries
  static Future<String> getCategoryImage(String category) async {
    final sanitizedCategory = category.trim();
    developer.log('🔍 Fetching image for category: $sanitizedCategory', name: 'UnsplashService');
    
    // 1. Check in-memory cache for this category
    if (_categoryImagesCache.containsKey(sanitizedCategory) && 
        _categoryImagesCache[sanitizedCategory]!.isNotEmpty) {
      final images = _categoryImagesCache[sanitizedCategory]!;
      final randomIndex = Random().nextInt(images.length);
      final imageUrl = images[randomIndex];
      developer.log('✅ Found and selected random image from cache for: $sanitizedCategory (index $randomIndex)', name: 'UnsplashService');
      return imageUrl;
    }

    // 2. Check local storage (persistence)
    final prefs = await SharedPreferences.getInstance();
    final cachedUrls = prefs.getStringList('cat_imgs_$sanitizedCategory');
    if (cachedUrls != null && cachedUrls.isNotEmpty) {
      developer.log('💾 Found local storage cache for: $sanitizedCategory (${cachedUrls.length} images)', name: 'UnsplashService');
      _categoryImagesCache[sanitizedCategory] = cachedUrls;
      final randomIndex = Random().nextInt(cachedUrls.length);
      return cachedUrls[randomIndex];
    }

    // 3. Fetch from Unsplash API with more results
    try {
      // Check connectivity first
      if (!await _hasInternet()) {
        developer.log('📡 No internet connection detected for $sanitizedCategory', name: 'UnsplashService', error: 'No internet connection');
        return _getFallbackUrl(sanitizedCategory);
      }

      developer.log('🌐 Calling Unsplash API for: $sanitizedCategory', name: 'UnsplashService');
      
      final uri = Uri.parse('$_baseUrl$_searchPath');
      
      // Use unique search queries by adding modifiers
      final modifiers = [
        'high quality',
        'professional',
        'premium',
        'best',
        'top rated',
        'trending',
        'popular',
        'featured',
        'excellent',
        'outstanding'
      ];
      
      // Select a random modifier to create unique search query
      final randomModifier = modifiers[Random().nextInt(modifiers.length)];
      final uniqueQuery = '$sanitizedCategory $randomModifier';
      
      // Add query parameters manually for better control
      final queryParams = {
        'query': uniqueQuery,
        'per_page': '10', // Fetch 10 results instead of 1
        'client_id': _accessKey,
        'orientation': 'landscape',
        'content_filter': 'high',
      };
      
      final fullUri = uri.replace(queryParameters: queryParams);
      
      developer.log('🔗 Request URL: $fullUri', name: 'UnsplashService');

      final response = await http.get(fullUri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          // Extract all image URLs
          final imageUrls = <String>[];
          for (final result in data['results']) {
            if (result['urls'] != null && result['urls']['regular'] != null) {
              imageUrls.add(result['urls']['regular']);
            }
          }
          
          if (imageUrls.isNotEmpty) {
            // Select random image
            final randomIndex = Random().nextInt(imageUrls.length);
            final imageUrl = imageUrls[randomIndex];
            
            developer.log('✨ Successfully fetched random image for $sanitizedCategory: $imageUrl (from ${imageUrls.length} results)', name: 'UnsplashService');
            
            // Save all images to cache
            _categoryImagesCache[sanitizedCategory] = imageUrls;
            await prefs.setStringList('cat_imgs_$sanitizedCategory', imageUrls);
            
            return imageUrl;
          } else {
            developer.log('⚠️ No valid image URLs found in results for $sanitizedCategory', name: 'UnsplashService');
          }
        } else {
          developer.log('⚠️ No results found for $sanitizedCategory on Unsplash', name: 'UnsplashService');
        }
      } else {
        developer.log('❌ Unsplash API Error: ${response.statusCode} - ${response.body}', name: 'UnsplashService', error: 'API returned ${response.statusCode}');
      }
    } on SocketException catch (e) {
      developer.log('🔌 Network Error (SocketException) for $sanitizedCategory: $e', name: 'UnsplashService', error: e);
      // Try fallback immediately on socket errors
      return _getFallbackUrl(sanitizedCategory);
    } on http.ClientException catch (e) {
      developer.log('🌐 HTTP Client Error for $sanitizedCategory: $e', name: 'UnsplashService', error: e);
      return _getFallbackUrl(sanitizedCategory);
    } catch (e) {
      developer.log('🚨 Unexpected Unsplash API Exception for $sanitizedCategory: $e', name: 'UnsplashService', error: e);
      return _getFallbackUrl(sanitizedCategory);
    }

    return _getFallbackUrl(sanitizedCategory);
  }

  /// Alias for getCategoryImage - used as getImageUrl in some places
  static Future<String?> getImageUrl(String query) async {
    try {
      return await getCategoryImage(query);
    } catch (e) {
      developer.log('❌ Error in getImageUrl for $query: $e', name: 'UnsplashService', error: e);
      return null;
    }
  }

  static String _getFallbackUrl(String category) {
    // Use the recommended test URL format: https://source.unsplash.com/400x400/?category
    final encodedCategory = Uri.encodeComponent(category);
    final fallback = 'https://source.unsplash.com/400x400/?$encodedCategory';
    developer.log('🔗 Using fallback URL for $category: $fallback', name: 'UnsplashService');
    return fallback;
  }
}
