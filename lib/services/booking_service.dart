import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';
import '../models/offer_model.dart';
import '../core/logging_service.dart';

/// Real-time Booking Service
/// Handles all booking operations with Firestore real-time listeners
class BookingService {
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference get _bookings => _firestore.collection('bookings');
  CollectionReference get _offers => _firestore.collection('offers');
  CollectionReference get _counterOffers =>
      _firestore.collection('counter_offers');

  // ========== CREATE BOOKING ==========

  /// Create a new booking request
  /// This will broadcast to nearby providers
  Future<String> createBooking({
    required String serviceCategory,
    required String serviceType,
    required String description,
    List<String>? images,
    double? budget,
    DateTime? preferredDate,
    String? preferredTime,
    required Map<String, dynamic> address,
    Map<String, dynamic>? customerLocation,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final booking = BookingModel(
        id: '', // Will be set by Firestore
        customerId: userId,
        serviceCategory: serviceCategory,
        serviceType: serviceType,
        description: description,
        images: images,
        budget: budget,
        preferredDate: preferredDate,
        preferredTime: preferredTime,
        address: address,
        customerLocation: customerLocation,
        status: 'searching_providers',
        createdAt: DateTime.now(),
      );

      final docRef = await _bookings.add(booking.toMap());

      Log.i('BookingService', '✅ Booking created: ${docRef.id}');
      Log.i('BookingService', '📢 Broadcasting to nearby providers...');

      // TODO: Trigger cloud function to notify nearby providers
      // This will be handled by Firebase Cloud Functions
      // await _notifyNearbyProviders(docRef.id, customerLocation, serviceType);

      return docRef.id;
    } catch (e) {
      Log.e('BookingService', '❌ Error creating booking: $e', ex: e);
      rethrow;
    }
  }

  // ========== REAL-TIME BOOKING LISTENERS ==========

  /// Listen to a specific booking in real-time
  Stream<BookingModel> listenToBooking(String bookingId) {
    return _bookings.doc(bookingId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw Exception('Booking not found');
      }
      return BookingModel.fromFirestore(snapshot);
    });
  }

  /// Listen to all bookings for current user (customer)
  Stream<List<BookingModel>> listenToUserBookings() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _bookings
        .where('customerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BookingModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Listen to active bookings only
  Stream<List<BookingModel>> listenToActiveBookings() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _bookings
        .where('customerId', isEqualTo: userId)
        .where(
          'status',
          whereIn: [
            'searching_providers',
            'offers_incoming',
            'offer_accepted',
            'payment_pending',
            'provider_assigned',
            'on_the_way',
            'arrived',
            'service_started',
          ],
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BookingModel.fromFirestore(doc))
              .toList();
        });
  }

  // ========== UPDATE BOOKING STATUS ==========

  /// Update booking status in real-time
  Future<void> updateBookingStatus(String bookingId, String newStatus) async {
    try {
      await _bookings.doc(bookingId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Log.i('BookingService', '✅ Booking status updated: $newStatus');
    } catch (e) {
      Log.e('BookingService', '❌ Error updating booking status: $e', ex: e);
      rethrow;
    }
  }

  /// Accept an offer and update booking
  Future<void> acceptOffer(
    String bookingId,
    String offerId,
    double acceptedPrice,
  ) async {
    try {
      // Update booking
      await _bookings.doc(bookingId).update({
        'status': 'offer_accepted',
        'acceptedOfferId': offerId,
        'acceptedPrice': acceptedPrice,
        'paymentStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Update offer status
      await _offers.doc(offerId).update({'status': 'accepted'});

      // Reject all other offers
      await _rejectOtherOffers(bookingId, offerId);

      Log.i('BookingService', '✅ Offer accepted: $offerId');
    } catch (e) {
      Log.e('BookingService', '❌ Error accepting offer: $e', ex: e);
      rethrow;
    }
  }

  /// Reject other offers when one is accepted
  Future<void> _rejectOtherOffers(
    String bookingId,
    String acceptedOfferId,
  ) async {
    final snapshot = await _offers
        .where('bookingId', isEqualTo: bookingId)
        .where('status', isEqualTo: 'pending')
        .get();

    for (var doc in snapshot.docs) {
      if (doc.id != acceptedOfferId) {
        await doc.reference.update({'status': 'rejected'});
      }
    }
  }

  // ========== REAL-TIME OFFERS ==========

  /// Listen to offers for a specific booking in real-time
  Stream<List<OfferModel>> listenToBookingOffers(String bookingId) {
    return _offers
        .where('bookingId', isEqualTo: bookingId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => OfferModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Get all offers (including accepted/rejected)
  Stream<List<OfferModel>> listenToAllBookingOffers(String bookingId) {
    return _offers
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => OfferModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Get offer count for a booking
  Stream<int> listenToOfferCount(String bookingId) {
    return _offers
        .where('bookingId', isEqualTo: bookingId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ========== CREATE OFFER ==========

  /// Provider sends an offer for a booking
  Future<String> sendOffer({
    required String bookingId,
    required String providerId,
    required String providerName,
    String? providerImage,
    required double providerRating,
    required int completedJobs,
    required double offeredPrice,
    String? eta,
    String? message,
    List<String>? includedServices,
  }) async {
    try {
      final offer = OfferModel(
        id: '',
        bookingId: bookingId,
        providerId: providerId,
        providerName: providerName,
        providerImage: providerImage,
        providerRating: providerRating,
        completedJobs: completedJobs,
        offeredPrice: offeredPrice,
        eta: eta,
        message: message,
        includedServices: includedServices,
        status: 'pending',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(
          const Duration(hours: 24),
        ), // 24 hour expiry
      );

      final docRef = await _offers.add(offer.toMap());

      // Update booking offer count
      await _bookings.doc(bookingId).update({
        'offersCount': FieldValue.increment(1),
        'status': 'offers_incoming',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Log.i('BookingService', '✅ Offer sent: ${docRef.id}');
      Log.i('BookingService', '🔔 Notifying customer...');

      // TODO: Send push notification to customer
      // await _sendNotificationToCustomer(bookingId, docRef.id);

      return docRef.id;
    } catch (e) {
      Log.e('BookingService', '❌ Error sending offer: $e', ex: e);
      rethrow;
    }
  }

  // ========== COUNTER-OFFER SYSTEM ==========

  /// Customer sends a counter-offer to a provider
  Future<String> sendCounterOffer({
    required String bookingId,
    required String originalOfferId,
    required String providerId,
    required double counterPrice,
    required String message,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final counterOffer = {
        'bookingId': bookingId,
        'customerId': userId,
        'providerId': providerId,
        'originalOfferId': originalOfferId,
        'counterPrice': counterPrice,
        'message': message,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 12)),
        ),
      };

      final docRef = await _counterOffers.add(counterOffer);

      // Update original offer status
      await _offers.doc(originalOfferId).update({'status': 'countered'});

      // Update booking
      await _bookings.doc(bookingId).update({
        'isCounterOfferActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Log.i('BookingService', '✅ Counter-offer sent: ${docRef.id}');
      Log.i('BookingService', '🔔 Notifying provider...');

      // TODO: Send push notification to provider
      // await _sendNotificationToProvider(bookingId, providerId, docRef.id);

      return docRef.id;
    } catch (e) {
      Log.e('BookingService', '❌ Error sending counter-offer: $e', ex: e);
      rethrow;
    }
  }

  /// Provider responds to counter-offer
  Future<void> respondToCounterOffer({
    required String counterOfferId,
    required String response, // 'accepted' or 'rejected'
    double? newOfferPrice,
    String? newMessage,
  }) async {
    try {
      await _counterOffers.doc(counterOfferId).update({
        'status': response,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      if (response == 'accepted' && newOfferPrice != null) {
        // Update the original offer with new price
        final counterOfferDoc = await _counterOffers.doc(counterOfferId).get();
        final counterOfferData = counterOfferDoc.data() as Map<String, dynamic>;
        final originalOfferId = counterOfferData['originalOfferId'];

        await _offers.doc(originalOfferId).update({
          'offeredPrice': newOfferPrice,
          'status': 'pending',
          'message': newMessage,
        });

        // Update booking
        final bookingId = counterOfferData['bookingId'];
        await _bookings.doc(bookingId).update({
          'isCounterOfferActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      Log.i('BookingService', '✅ Counter-offer response: $response');
    } catch (e) {
      Log.e('BookingService', '❌ Error responding to counter-offer: $e', ex: e);
      rethrow;
    }
  }

  /// Listen to counter-offers for a booking
  Stream<List<Map<String, dynamic>>> listenToCounterOffers(String bookingId) {
    return _counterOffers
        .where('bookingId', isEqualTo: bookingId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  // ========== PAYMENT UPDATE ==========

  /// Update payment status after successful payment
  Future<void> updatePaymentStatus({
    required String bookingId,
    required String paymentId,
    required String paymentStatus,
    required double totalAmount,
  }) async {
    try {
      await _bookings.doc(bookingId).update({
        'paymentId': paymentId,
        'paymentStatus': paymentStatus,
        'totalAmount': totalAmount,
        'status': paymentStatus == 'paid'
            ? 'provider_assigned'
            : 'payment_pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Log.p('BookingService', '✅ Payment status updated: $paymentStatus');
    } catch (e) {
      Log.e('BookingService', '❌ Error updating payment status: $e', ex: e);
      rethrow;
    }
  }

  // ========== CANCEL BOOKING ==========

  /// Cancel a booking
  Future<void> cancelBooking(String bookingId, String reason) async {
    try {
      await _bookings.doc(bookingId).update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Reject all pending offers
      final snapshot = await _offers
          .where('bookingId', isEqualTo: bookingId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.update({'status': 'rejected'});
      }

      Log.i('BookingService', '✅ Booking cancelled');
    } catch (e) {
      Log.e('BookingService', '❌ Error cancelling booking: $e', ex: e);
      rethrow;
    }
  }

  // ========== HELPER METHODS ==========

  /// Get booking by ID (one-time fetch)
  Future<BookingModel?> getBooking(String bookingId) async {
    try {
      final doc = await _bookings.doc(bookingId).get();
      if (!doc.exists) return null;
      return BookingModel.fromFirestore(doc);
    } catch (e) {
      Log.e('BookingService', '❌ Error fetching booking: $e', ex: e);
      return null;
    }
  }

  /// Get offer by ID (one-time fetch)
  Future<OfferModel?> getOffer(String offerId) async {
    try {
      final doc = await _offers.doc(offerId).get();
      if (!doc.exists) return null;
      return OfferModel.fromFirestore(doc);
    } catch (e) {
      Log.e('BookingService', '❌ Error fetching offer: $e', ex: e);
      return null;
    }
  }
}
