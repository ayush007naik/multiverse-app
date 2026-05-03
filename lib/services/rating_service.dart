import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingService {
  static Future<void> submitRating({
    required String orderId,
    required int rating,
    String? review,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Save rating to Firestore
      await FirebaseFirestore.instance.collection('ratings').add({
        'orderId': orderId,
        'userId': user.uid,
        'rating': rating,
        'review': review ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update order with rating
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'userRating': rating,
        'userReview': review ?? '',
        'ratedAt': FieldValue.serverTimestamp(),
      });

      // Update vendor/shop rating
      await _updateVendorRating(orderId, rating);
    } catch (e) {
      throw Exception('Failed to submit rating: $e');
    }
  }

  static Future<void> _updateVendorRating(String orderId, int newRating) async {
    try {
      // Get order to find vendor/shop
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final shopId = orderData['shopId'];

      if (shopId == null) return;

      // Get all ratings for this shop
      final ratingsQuery = await FirebaseFirestore.instance
          .collection('ratings')
          .where('orderId', isEqualTo: orderId)
          .get();

      if (ratingsQuery.docs.isEmpty) return;

      // Calculate average rating
      final ratings = ratingsQuery.docs.map((doc) => doc.data()['rating'] as int).toList();
      final averageRating = ratings.reduce((a, b) => a + b) / ratings.length;

      // Update shop rating
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'rating': averageRating,
        'totalRatings': ratings.length,
        'lastRatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Don't throw error for rating update failure
      print('Error updating vendor rating: $e');
    }
  }

  static Future<Map<String, dynamic>?> getOrderRating(String orderId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final ratingQuery = await FirebaseFirestore.instance
          .collection('ratings')
          .where('orderId', isEqualTo: orderId)
          .where('userId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (ratingQuery.docs.isEmpty) return null;

      return ratingQuery.docs.first.data();
    } catch (e) {
      print('Error getting order rating: $e');
      return null;
    }
  }

  static Future<double> getShopAverageRating(String shopId) async {
    try {
      final shopDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .get();

      if (!shopDoc.exists) return 0.0;

      final data = shopDoc.data();
      return (data?['rating'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      print('Error getting shop rating: $e');
      return 0.0;
    }
  }

  static Future<int> getShopTotalRatings(String shopId) async {
    try {
      final shopDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .get();

      if (!shopDoc.exists) return 0;

      final data = shopDoc.data();
      return (data?['totalRatings'] as int?) ?? 0;
    } catch (e) {
      print('Error getting shop total ratings: $e');
      return 0;
    }
  }

  static Future<List<Map<String, dynamic>>> getShopReviews(String shopId) async {
    try {
      // Get all orders for this shop
      final ordersQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('shopId', isEqualTo: shopId)
          .where('userRating', isGreaterThan: 0)
          .get();

      final reviews = <Map<String, dynamic>>[];

      for (final orderDoc in ordersQuery.docs) {
        final orderData = orderDoc.data();
        final rating = orderData['userRating'] as int?;
        final review = orderData['userReview'] as String?;

        if (rating != null && rating > 0) {
          reviews.add({
            'orderId': orderDoc.id,
            'rating': rating,
            'review': review ?? '',
            'createdAt': orderData['ratedAt'],
            'customerName': orderData['address']?['name'] ?? 'Anonymous',
          });
        }
      }

      // Sort by creation date (newest first)
      reviews.sort((a, b) {
        final aDate = a['createdAt'] as Timestamp?;
        final bDate = b['createdAt'] as Timestamp?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      return reviews;
    } catch (e) {
      print('Error getting shop reviews: $e');
      return [];
    }
  }
}