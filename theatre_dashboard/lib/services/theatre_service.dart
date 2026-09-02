import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TheatreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUid => _auth.currentUser?.uid ?? '';

  // ============================================================================
  // THEATRE PROFILE
  // ============================================================================
  
  Stream<DocumentSnapshot> getTheatreProfile() {
    return _firestore.collection('theatres').doc(currentUid).snapshots();
  }

  Future<void> updateTheatreProfile(Map<String, dynamic> data) async {
    await _firestore.collection('theatres').doc(currentUid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch all approved movies from global database (for show creation dropdowns)
  Stream<QuerySnapshot> getMovies() {
    return _firestore
        .collection('movies')
        .where('status', isEqualTo: 'approved')
        .snapshots();
  }

  /// Fetch all movies from global database (for overview stats/charts)
  Stream<QuerySnapshot> getAllGlobalMovies() {
    return _firestore.collection('movies').snapshots();
  }

  /// Fetch all approved movies from the global database
  Stream<QuerySnapshot> getGlobalMovies() {
    return _firestore
        .collection('movies')
        .where('status', isEqualTo: 'approved')
        .snapshots();
  }

  /// Search global movies by title (client-side filter for flexible matching)
  Future<List<QueryDocumentSnapshot>> searchGlobalMovies(String query) async {
    final snapshot = await _firestore
        .collection('movies')
        .where('status', isEqualTo: 'approved')
        .get();
    final lowerQuery = query.toLowerCase();
    return snapshot.docs.where((doc) {
      final data = doc.data();
      final title = (data['title'] ?? '').toString().toLowerCase();
      return title.contains(lowerQuery);
    }).toList();
  }

  /// Check for similar movies before requesting a new one (duplicate prevention)
  Future<List<QueryDocumentSnapshot>> findSimilarMovies(String movieName) async {
    final snapshot = await _firestore.collection('movies').get();
    final lowerName = movieName.toLowerCase().trim();
    return snapshot.docs.where((doc) {
      final data = doc.data();
      final title = (data['title'] ?? '').toString().toLowerCase().trim();
      // Check for exact match, contains, or high similarity
      return title == lowerName ||
          title.contains(lowerName) ||
          lowerName.contains(title);
    }).toList();
  }

  /// Request a new movie to be added to the global database
  Future<void> requestNewMovie(Map<String, dynamic> movieData) async {
    final theatreSnap = await getTheatreProfile().first;
    final theatreData = theatreSnap.data();
    final theatreName = theatreData?['name'] ?? theatreData?['cinemaName'] ?? 'Unknown Theatre';

    // Create the movie request
    await _firestore.collection('movie_requests').add({
      ...movieData,
      'requestedByTheatreId': currentUid,
      'requestedByTheatreName': theatreName,
      'status': 'pending',
      'adminRemarks': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notify admin about new movie request
    await _firestore.collection('admin_notifications').add({
      'type': 'new_movie_request',
      'title': 'New Movie Request',
      'body': '$theatreName has requested to add "${movieData['title']}" to the global database.',
      'movieName': movieData['title'],
      'requestedByTheatreId': currentUid,
      'requestedByTheatreName': theatreName,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get movies requested by this theatre
  Stream<QuerySnapshot> getMyMovieRequests() {
    return _firestore
        .collection('movie_requests')
        .where('requestedByTheatreId', isEqualTo: currentUid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get movies currently being shown at this theatre (from shows collection)
  Stream<QuerySnapshot> getMyActiveMovies() {
    // This fetches unique movie IDs from the shows collection for this theatre
    return _firestore
        .collection('shows')
        .where('theatreId', isEqualTo: currentUid)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  /// Add a movie to this theatre's lineup (shown in the "My Shows" tab)
  Future<void> addMyMovie(Map<String, dynamic> movie) async {
    final docId = '${currentUid}_${movie['movieId']}';
    await _firestore.collection('theatre_movies').doc(docId).set({
      ...movie,
      'theatreId': currentUid,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Movies added to this theatre's lineup
  Stream<QuerySnapshot> getMyMovies() {
    return _firestore
        .collection('theatre_movies')
        .where('theatreId', isEqualTo: currentUid)
        .snapshots();
  }

  /// Remove a movie from this theatre's lineup
  Future<void> removeMyMovie(String docId) async {
    await _firestore.collection('theatre_movies').doc(docId).delete();
  }

  Future<void> updateMovie(String movieId, Map<String, dynamic> movieData) async {
    // Note: Theatres can only update their REQUESTS if pending, not the global movie
    await _firestore.collection('movie_requests').doc(movieId).update(movieData);
  }

  Future<void> deleteMovie(String movieId) async {
    // Theatres delete shows, not movies. If it's a request:
    await _firestore.collection('movie_requests').doc(movieId).delete();
  }

  // ============================================================================
  // SHOW MANAGEMENT
  // ============================================================================

  Stream<QuerySnapshot> getShows() {
    return _firestore
        .collection('shows')
        .where('theatreId', isEqualTo: currentUid)
        .snapshots();
  }

  Future<void> createShow(Map<String, dynamic> showData) async {
    await _firestore.collection('shows').add({
      ...showData,
      'theatreId': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }

  Future<void> updateShow(String showId, Map<String, dynamic> showData) async {
    await _firestore.collection('shows').doc(showId).update({
      ...showData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteShow(String showId) async {
    await _firestore.collection('shows').doc(showId).delete();
  }

  // ============================================================================
  // BOOKING MANAGEMENT
  // ============================================================================

  /// Get bookings ordered by creation time (may exclude documents missing createdAt)
  Stream<QuerySnapshot> getBookings() {
    return _firestore
        .collection('movie_bookings')
        .where('theatreId', isEqualTo: currentUid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get all bookings without ordering to ensure we don't skip docs missing createdAt.
  /// Use this for revenue and statistical calculations.
  Stream<QuerySnapshot> getAllBookings() {
    return _firestore
        .collection('movie_bookings')
        .where('theatreId', isEqualTo: currentUid)
        .snapshots();
  }

  // Helper methods for robust data handling
  static double parseRevenue(Map<String, dynamic> data) {
    final val = data['ticketPrice'] ?? data['totalAmount'] ?? data['amount'] ?? 0;
    if (val is String) {
      return double.tryParse(val) ?? 0;
    } else if (val is num) {
      return val.toDouble();
    }
    return 0;
  }

  static bool isConfirmed(Map<String, dynamic> data) {
    final bStatus = (data['bookingStatus'] ?? data['status'] ?? '').toString().toLowerCase();
    return bStatus == 'confirmed' || bStatus == 'success';
  }

  static bool isOffline(Map<String, dynamic> data) {
    return data['isOffline'] == true ||
        data['paymentMethod'] == 'manual' ||
        data['paymentMode'] == 'Offline' ||
        data['paymentMethod'] == 'Offline';
  }

  // ============================================================================
  // ANALYTICS & REVENUE
  // ============================================================================

  Stream<QuerySnapshot> getConfirmedBookings() {
    return _firestore
        .collection('movie_bookings')
        .where('theatreId', isEqualTo: currentUid)
        .where('status', isEqualTo: 'confirmed')
        .snapshots();
  }

  // ============================================================================
  // STAFF MANAGEMENT
  // ============================================================================

  Stream<QuerySnapshot> getStaff() {
    return _firestore
        .collection('staff')
        .where('theatreId', isEqualTo: currentUid)
        .snapshots();
  }

  Future<Map<String, dynamic>?> getStaffById(String staffId) async {
    final doc = await _firestore.collection('staff').doc(staffId).get();
    if (doc.exists) {
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    }
    return null;
  }

  /// Create staff with Firebase Auth account
  Future<String?> addStaffWithAuth(Map<String, dynamic> staffData) async {
    try {
      final email = staffData['email'] as String;
      final password = staffData['password'] as String;
      final adminPassword = staffData['adminPassword'] as String?;
      final adminEmail = _auth.currentUser?.email;

      if (adminEmail == null) {
        return 'No authenticated admin user found. Please login again.';
      }
      if (adminPassword == null || adminPassword.isEmpty) {
        return 'Admin password is required to create staff.';
      }

      // Save admin data before createUserWithEmailAndPassword
      // (which signs out the current user and signs in as the new staff)
      final savedAdminEmail = adminEmail;
      final savedAdminPassword = adminPassword;
      final savedAdminUid = _auth.currentUser!.uid;

      // Create Firebase Auth account (signs in as the new staff user)
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final staffId = credential.user!.uid;

      // Re-authenticate as admin BEFORE writing to Firestore,
      // so the write runs with the admin's Firestore permissions
      await _auth.signInWithEmailAndPassword(
        email: savedAdminEmail,
        password: savedAdminPassword,
      );

      // Save staff document with auth UID as document ID
      await _firestore.collection('staff').doc(staffId).set({
        'staffId': staffId,
        'theatreId': savedAdminUid,
        'name': staffData['name'],
        'email': email,
        'mobile': staffData['mobile'] ?? '',
        'role': staffData['role'],
        'isActive': staffData['isActive'] ?? true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Failed to create staff account';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateStaff(String staffId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('staff').doc(staffId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteStaff(String staffId) async {
    try {
      // Delete Firestore document
      await _firestore.collection('staff').doc(staffId).delete();

      // Try to delete Auth account
      try {
        await _auth.currentUser?.getIdToken(true);
        // We need admin SDK to delete users, so we mark as deleted instead
        // Actual deletion can be done via Firebase Console or Cloud Function
        await _firestore.collection('staff').doc(staffId).set({
          'isDeleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
        }, const SetOptions(merge: true));
      } catch (_) {}

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> toggleStaffActive(String staffId, bool isActive) async {
    try {
      await _firestore.collection('staff').doc(staffId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> resetStaffPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Stream<QuerySnapshot> searchStaff(String query) {
    // We fetch all staff and filter client-side for flexibility
    return _firestore
        .collection('staff')
        .where('theatreId', isEqualTo: currentUid)
        .snapshots();
  }

  Stream<QuerySnapshot> getStaffByRole(String role) {
    return _firestore
        .collection('staff')
        .where('theatreId', isEqualTo: currentUid)
        .where('role', isEqualTo: role)
        .snapshots();
  }

  // ============================================================================
  // COUPONS & OFFERS
  // ============================================================================

  Stream<QuerySnapshot> getCoupons() {
    return _firestore
        .collection('coupons')
        .where('createdBy', isEqualTo: currentUid)
        .snapshots();
  }

  Future<void> createCoupon(Map<String, dynamic> couponData) async {
    await _firestore.collection('coupons').add({
      ...couponData,
      'couponCode': couponData['code'] ?? couponData['couponCode'],
      'createdBy': currentUid,
      'theatreId': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCoupon(String couponId) async {
    await _firestore.collection('coupons').doc(couponId).delete();
  }

  Future<void> toggleCouponActive(String couponId, bool isActive) async {
    await _firestore.collection('coupons').doc(couponId).update({'isActive': isActive});
  }

  // ============================================================================
  // NOTIFICATIONS
  // ============================================================================

  Stream<QuerySnapshot> getNotifications() {
    return _firestore
        .collection('theatre_notifications')
        .where('theatreId', isEqualTo: currentUid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> sendNotification(String title, String body) async {
    await _firestore.collection('theatre_notifications').add({
      'theatreId': currentUid,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'sent': false,
    });
  }

  // ============================================================================
  // SEAT BOOKING (Manual mark/unmark)
  // ============================================================================

  Future<void> updateSeatStatus(String showId, String seatId, String newStatus) async {
    final showRef = _firestore.collection('shows').doc(showId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(showRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final seatStatus = Map<String, dynamic>.from(data['seatStatus'] ?? {});
      final oldStatus = seatStatus[seatId] ?? 'available';

      if (oldStatus == newStatus) return;

      seatStatus[seatId] = newStatus;

      int availableSeats = data['availableSeats'] ?? 0;
      
      // Update available count logic
      if (oldStatus == 'available' && (newStatus == 'booked' || newStatus == 'blocked')) {
        availableSeats--;
      } else if ((oldStatus == 'booked' || oldStatus == 'blocked') && newStatus == 'available') {
        availableSeats++;
      }

      transaction.update(showRef, {
        'seatStatus': seatStatus,
        'availableSeats': availableSeats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Get all confirmed/pending bookings for a specific show
  Stream<QuerySnapshot> getBookingsForShow(String showId) {
    return _firestore
        .collection('movie_bookings')
        .where('theatreId', isEqualTo: currentUid)
        .where('showId', isEqualTo: showId)
        .snapshots();
  }

  /// Mark seats as booked manually (walk-in / phone booking)
  Future<String> createOfflineBooking({
    required String showId,
    required String movieId,
    required String movieTitle,
    required String moviePoster,
    required String showTime,
    required String screen,
    required List<String> seats,
    required double totalAmount,
    required String paymentMode,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerUid,
    bool sendSMS = false,
    bool sendWhatsApp = true,
    bool sendEmail = false,
  }) async {
    final showRef = _firestore.collection('shows').doc(showId);
    
    // 1. Resolve the correct Theatre ID (handles staff accounts)
    final showSnapInitial = await showRef.get();
    if (!showSnapInitial.exists) throw Exception("Show not found");
    final theatreId = showSnapInitial.data()?['theatreId'] ?? currentUid;

    final bookingRef = _firestore.collection('movie_bookings').doc();
    
    // 2. Get theatre details using the resolved theatreId
    final theatreSnap = await _firestore.collection('theatres').doc(theatreId).get();
    final theatreData = theatreSnap.data();
    final theatreName = theatreData?['name'] ?? theatreData?['cinemaName'] ?? 'MULTIVERSE';
    final theatreAddress = theatreData?['address'] ?? '';

    final ticketNumber = 'OFF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    await _firestore.runTransaction((transaction) async {
      final showSnap = await transaction.get(showRef);
      if (!showSnap.exists) throw Exception("Show not found");

      final showData = showSnap.data() as Map<String, dynamic>;
      final seatStatus = Map<String, dynamic>.from(showData['seatStatus'] ?? {});
      
      // Check if seats are still available
      for (var seatId in seats) {
        if (seatStatus[seatId] != null && seatStatus[seatId] != 'available') {
          throw Exception("Seat $seatId is already booked");
        }
      }

      // Mark seats as booked
      for (var seatId in seats) {
        seatStatus[seatId] = 'booked';
      }

      int availableSeats = (showData['availableSeats'] ?? 0) - seats.length;

      // Update show
      transaction.update(showRef, {
        'seatStatus': seatStatus,
        'availableSeats': availableSeats,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Parse date from showTime (format: "dd MMM yyyy • hh:mm a")
      String isoDate = '';
      String timeOnly = '';
      try {
        final parsed = DateFormat('dd MMM yyyy • hh:mm a').parse(showTime);
        isoDate = DateFormat('yyyy-MM-dd').format(parsed);
        timeOnly = DateFormat('hh:mm a').format(parsed);
      } catch (_) {
        isoDate = DateTime.now().toIso8601String().substring(0, 10);
        if (showTime.contains('•')) {
          timeOnly = showTime.split('•').last.trim();
        } else {
          // Fallback: extract just the time portion so the DB time column accepts it
          timeOnly = RegExp(r'\d{1,2}:\d{2}\s*[APap][Mm]').firstMatch(showTime)?.group(0) ?? showTime;
        }
      }

      // Create booking with correct theatreId
      final bookingData = {
        'bookingId': bookingRef.id,
        'ticketNumber': ticketNumber,
        'theatreId': theatreId,
        'staffId': currentUid, // Keep track of which staff member sold it
        'theatreName': theatreName,
        'theatreAddress': theatreAddress,
        'showId': showId,
        'movieId': movieId,
        'movieTitle': movieTitle,
        'movieName': movieTitle,
        'moviePoster': moviePoster,
        'showTime': timeOnly,
        'date': isoDate,
        'showDate': isoDate,
        'bookingDate': isoDate,
        'time': timeOnly,
        'screen': screen,
        'seats': seats,
        'totalAmount': totalAmount,
        'finalAmount': totalAmount,
        'totalPaid': totalAmount,
        'paymentMethod': paymentMode,
        'customerName': customerName ?? 'Walk-in',
        'customerPhone': customerPhone ?? '',
        'customerEmail': customerEmail ?? '',
        'status': 'confirmed',
        'bookingStatus': 'confirmed',
        'isOffline': true,
        'isUsed': false,
        'customerUid': customerUid,
        'userId': customerUid,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      transaction.set(bookingRef, bookingData);

      // If notification requested
      if (sendSMS || sendEmail || sendWhatsApp) {
        final notificationRef = _firestore.collection('ticket_notifications').doc();
        transaction.set(notificationRef, {
          'bookingId': bookingRef.id,
          'theatreId': theatreId,
          'phone': customerPhone,
          'email': customerEmail,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });

    return bookingRef.id;
  }

  /// Mark seats as booked manually (Legacy - replaced by createOfflineBooking)
  Future<String> markSeatsBooked({
    required String showId,
    required String movieTitle,
    required String showTime,
    required List<String> seats,
    required String screen,
    double totalAmount = 0,
  }) async {
    final timeOnly = showTime.contains('•')
        ? showTime.split('•').last.trim()
        : (RegExp(r'\d{1,2}:\d{2}\s*[APap][Mm]').firstMatch(showTime)?.group(0) ?? showTime);
    final docRef = await _firestore.collection('movie_bookings').add({
      'theatreId': currentUid,
      'showId': showId,
      'movieTitle': movieTitle,
      'showTime': timeOnly,
      'screen': screen,
      'seats': seats,
      'totalAmount': totalAmount,
      'ticketPrice': totalAmount, // For manual bookings, ticket price is the total amount
      'status': 'confirmed',
      'bookingStatus': 'confirmed',
      'paymentMethod': 'manual',
      'userName': 'Walk-in',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Unmark (cancel) a manual booking
  Future<void> unmarkSeatBooking(String bookingId) async {
    await _firestore.collection('movie_bookings').doc(bookingId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  /// Full cancel: frees seats in show doc + updates booking + triggers notification
  Future<void> cancelBooking(String bookingId, Map<String, dynamic> bookingData) async {
    final showId = bookingData['showId'] ?? '';
    final seats = List<String>.from(bookingData['seats'] ?? []);

    await _firestore.runTransaction((transaction) async {
      // Free seats in show document
      if (showId.isNotEmpty && seats.isNotEmpty) {
        final showRef = _firestore.collection('shows').doc(showId);
        final showSnap = await transaction.get(showRef);
        if (showSnap.exists) {
          final showData = showSnap.data() as Map<String, dynamic>;
          final seatStatus = Map<String, dynamic>.from(showData['seatStatus'] ?? {});
          for (final seatId in seats) {
            if (seatStatus[seatId] == 'booked') {
              seatStatus[seatId] = 'available';
            }
          }
          int availableSeats = (showData['availableSeats'] ?? 0) + seats.length;
          transaction.update(showRef, {
            'seatStatus': seatStatus,
            'availableSeats': availableSeats,
          });
        }
      }

      // Update booking to cancelled + trigger notification
      transaction.update(_firestore.collection('movie_bookings').doc(bookingId), {
        'status': 'cancelled',
        'bookingStatus': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'processingStatus': 'pending_cancellation',
      });
    });
  }

  // ============================================================================
  // PAYOUTS
  // ============================================================================

  /// Get all payouts for this theatre
  Stream<QuerySnapshot> getPayouts() {
    return _firestore
        .collection('payouts')
        .where('recipientId', isEqualTo: currentUid)
        .where('recipientType', isEqualTo: 'theatre')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Request a payout
  Future<void> requestPayout({
    required double amount,
    required String payoutMethod,
    required Map<String, dynamic> payoutDetails,
    required double totalEarned,
    required double paidOut,
    required double pendingPayout,
  }) async {
    final theatreSnap = await getTheatreProfile().first;
    final theatreData = theatreSnap.data();
    final theatreName = theatreData?['name'] ?? theatreData?['cinemaName'] ?? 'Unknown Theatre';

    final Map<String, dynamic> payload = {
      'theatreId': currentUid,
      'partnerId': currentUid, // Added for compatibility with global payout listeners
      'theatreName': theatreName,
      'partnerName': theatreName,
      'amount': amount,
      'method': payoutMethod,
      'payoutMethod': payoutMethod,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'requestedAt': FieldValue.serverTimestamp(),
      'category': 'Theatre Partner',
    };

    payload['bankDetails'] = {
      'accountHolder': payoutDetails['name'],
      'accountNumber': payoutDetails['accountNumber'],
      'ifsc': payoutDetails['ifscCode'],
    };
    payload['payoutDetails'] = payoutDetails;

    // Save to unified payouts collection
    await _firestore.collection('payouts').add({
      ...payload,
      'recipientType': 'theatre',
      'recipientId': currentUid,
      'recipientName': theatreName,
    });

    // Also notify admin
    await _firestore.collection('admin_notifications').add({
      'type': 'payout_request',
      'title': 'New Payout Request',
      'body': '$theatreName has requested a payout of ₹${amount.toStringAsFixed(2)}',
      'amount': amount,
      'theatreId': currentUid,
      'theatreName': theatreName,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Re-send notification
  Future<void> resendNotification(String bookingId, {bool sms = false, bool whatsapp = false, bool email = false}) async {
    final bookingSnap = await _firestore.collection('movie_bookings').doc(bookingId).get();
    if (!bookingSnap.exists) return;
    
    final data = bookingSnap.data()!;
    // Resolve the correct theatreId from the booking itself to handle staff requests
    final theatreId = data['theatreId'] ?? currentUid;
    
    await _firestore.collection('ticket_notifications').add({
      'bookingId': bookingId,
      'theatreId': theatreId,
      'phone': data['customerPhone'],
      'email': data['customerEmail'],
      'sendSMS': sms,
      'sendWhatsApp': whatsapp,
      'sendEmail': email,
      'status': 'pending',
      'bookingData': data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
