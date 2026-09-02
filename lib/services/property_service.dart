import 'package:db_compat/db_compat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/logging_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/property_model.dart';

/// Service for managing real estate properties with real-time Firestore integration
class PropertyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _kPropertyCacheKey = 'cached_active_properties';
  List<Property>? _memoryCache;

  Future<void> _cacheProperties(List<Property> properties) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = properties.map((p) => p.toMap()).toList();
      await prefs.setString(_kPropertyCacheKey, jsonEncode(data));
      _memoryCache = properties;
    } catch (e) {
      Log.e('PropertyService', 'Error caching properties: $e');
    }
  }

  Future<List<Property>> getCachedProperties() async {
    if (_memoryCache != null) return _memoryCache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kPropertyCacheKey);
      if (cached != null) {
        final List<dynamic> decoded = jsonDecode(cached);
        _memoryCache = decoded
            .map((m) => Property.fromMap(m, m['id'] ?? ''))
            .toList();
        return _memoryCache!;
      }
    } catch (e) {
      Log.e('PropertyService', 'Error loading cached properties: $e');
    }
    return [];
  }

  List<Property> _processExpiry(
    List<Property> properties, {
    bool includeExpired = false,
  }) {
    final now = DateTime.now();
    return properties
        .map((p) {
          if (p.planExpiry != null &&
              p.planExpiry!.isBefore(now) &&
              p.plan != 'free') {
            return Property(
              id: p.id,
              title: p.title,
              type: p.type,
              category: p.category,
              price: p.price,
              location: p.location,
              city: p.city,
              description: p.description,
              images: p.images,
              amenities: p.amenities,
              area: p.area,
              beds: p.beds,
              baths: p.baths,
              bathrooms: p.bathrooms,
              ownerName: p.ownerName,
              ownerPhone: p.ownerPhone,
              sellerId: p.sellerId,
              status: p.status,
              isFeatured: false,
              plan: 'free',
              isVerified: false,
              brokerName: p.brokerName,
              brokerPhone: p.brokerPhone,
              mapLocation: p.mapLocation,
              createdAt: p.createdAt,
              isActive: p.isActive,
              showFeaturedBadge: false,
              propertyCardBorder: 'none',
              showVerifiedBadge: false,
              visibilityScore: 0,
              listingExpiry: p.listingExpiry,
              planExpiry: p.planExpiry,
              planStartTime: p.planStartTime,
            );
          }
          return p;
        })
        .where((p) {
          return includeExpired ||
              p.listingExpiry == null ||
              p.listingExpiry!.isAfter(now);
        })
        .toList();
  }

  /// Upload property images to Firebase Storage
  Future<List<String>> uploadPropertyImages(
    String propertyId,
    List<XFile> images,
  ) async {
    Log.i('PropertyService', 'Starting parallel upload of ${images.length} images for property $propertyId');

    final List<Future<String?>> uploadTasks = images.asMap().entries.map((
      entry,
    ) async {
      int i = entry.key;
      XFile image = entry.value;
      try {
        String fileName =
            'prop_${propertyId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        Reference ref = _storage.ref().child(
          'properties/$propertyId/$fileName',
        );

        final bytes = await image.readAsBytes();
        UploadTask uploadTask = ref.putData(
          bytes,
          const SettableMetadata(contentType: 'image/jpeg'),
        );

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        Log.i('PropertyService', 'Uploaded image $i: $downloadUrl');
        return downloadUrl;
      } catch (e) {
        Log.e('PropertyService', 'Error uploading image $i: $e');
        return null;
      }
    }).toList();

    final List<String?> results = await Future.wait(uploadTasks);
    final List<String> imageUrls = results.whereType<String>().toList();

    Log.i('PropertyService', 'Finished uploading. Total successful: ${imageUrls.length} / ${images.length}');
    return imageUrls;
  }

  Stream<List<Property>> streamActiveProperties() {
    return _firestore
        .collection('properties')
        .where('isActive', isEqualTo: true)
        .where('status', whereIn: ['approved', 'available'])
        .snapshots()
        .map((snapshot) {
          final properties = _processExpiry(
            snapshot.docs
                .map((doc) => Property.fromMap(doc.data(), doc.id))
                .toList(),
          );

          final filtered =
              properties.where((property) {
                return property.isActive;
              }).toList()..sort((a, b) {
                int cmp = b.visibilityScore.compareTo(a.visibilityScore);
                if (cmp != 0) return cmp;
                return b.createdAt.compareTo(a.createdAt);
              });

          _cacheProperties(filtered);
          return filtered;
        });
  }

  Stream<List<Property>> streamPropertiesByBroker(String brokerId) {
    return _firestore
        .collection('properties')
        .where('sellerId', isEqualTo: brokerId)
        .snapshots()
        .map((snapshot) {
          return _processExpiry(
            snapshot.docs
                .map((doc) => Property.fromMap(doc.data(), doc.id))
                .toList(),
            includeExpired: true,
          );
        });
  }

  Stream<List<Property>> streamAllProperties() {
    return _firestore.collection('properties').snapshots().map((snapshot) {
      return _processExpiry(
        snapshot.docs
            .map((doc) => Property.fromMap(doc.data(), doc.id))
            .toList(),
      );
    });
  }

  Stream<List<Map<String, dynamic>>> streamLeadsForBroker(String brokerId) {
    return _firestore.collection('property_leads').snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['sellerId'] == brokerId || data['brokerId'] == brokerId;
          })
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    });
  }

  Stream<QuerySnapshot> streamAllLeads() {
    return _firestore.collection('property_leads').snapshots();
  }

  Stream<List<Map<String, dynamic>>> streamSiteVisitsForBroker(
    String brokerId,
  ) {
    return _firestore.collection('site_visits').snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['sellerId'] == brokerId || data['brokerId'] == brokerId;
          })
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    });
  }

  Stream<QuerySnapshot> streamAllSiteVisits() {
    return _firestore.collection('site_visits').snapshots();
  }

  Future<bool> hasActiveSiteVisit(String propertyId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final siteVisits =
            userDoc.data()?['siteVisits'] as Map<String, dynamic>?;
        if (siteVisits != null) {
          final value = siteVisits[propertyId];
          if (value != null) {
            DateTime expiry;
            if (value is Timestamp) {
              expiry = value.toDate();
            } else if (value is String) {
              expiry = DateTime.tryParse(value) ?? DateTime(2000);
            } else {
              return false;
            }
            if (expiry.isAfter(DateTime.now())) return true;
          }
        }
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final visits =
        jsonDecode(prefs.getString('siteVisits') ?? '{}')
            as Map<String, dynamic>;
    final data = visits[propertyId] as Map<String, dynamic>?;
    if (data == null) return false;

    final expiryStr = data['expiresAt'] as String?;
    if (expiryStr == null) return false;

    final expiry = DateTime.tryParse(expiryStr);
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  Future<void> saveUserSiteVisit({
    required String propertyId,
    required String propertyTitle,
    required DateTime visitDate,
    required String timeStr,
    String? buyerName,
    String? buyerPhone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final visitEnd =
        _parseTimeToDateTime(visitDate, timeStr) ??
        visitDate.add(const Duration(hours: 1));

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'siteVisits': {propertyId: Timestamp.fromDate(visitEnd)},
        'siteVisitsData': {
          propertyId: {
            'propertyId': propertyId,
            'propertyTitle': propertyTitle,
            'date': Timestamp.fromDate(visitDate),
            'time': timeStr,
            'expiresAt': Timestamp.fromDate(visitEnd),
            'status': 'confirmed',
            'buyerName': buyerName ?? user.displayName ?? '',
            'buyerPhone': buyerPhone ?? user.phoneNumber ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          },
        },
      }, const SetOptions(merge: true));
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final visits =
        jsonDecode(prefs.getString('siteVisits') ?? '{}')
            as Map<String, dynamic>;
    visits[propertyId] = {
      'expiresAt': visitEnd.toIso8601String(),
      'propertyTitle': propertyTitle,
      'date': visitDate.toIso8601String(),
      'time': timeStr,
      'buyerName': buyerName ?? user.displayName ?? '',
      'buyerPhone': buyerPhone ?? user.phoneNumber ?? '',
    };
    await prefs.setString('siteVisits', jsonEncode(visits));
  }

  DateTime? _parseTimeToDateTime(DateTime date, String timeStr) {
    try {
      final cleaned = timeStr.trim().toLowerCase();
      int hour, minute;

      if (cleaned.contains('am') || cleaned.contains('pm')) {
        final isPm = cleaned.contains('pm');
        final parts = cleaned
            .replaceAll(RegExp(r'[ap]m'), '')
            .trim()
            .split(':');
        hour = int.parse(parts[0].trim());
        minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
        if (isPm && hour != 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
      } else {
        final parts = cleaned.split(':');
        hour = int.parse(parts[0].trim());
        minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
      }

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUserSiteVisits() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final visits = <Map<String, dynamic>>[];

    try {
      final snapshot = await _firestore
          .collection('site_visits')
          .where('buyerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'cancelled') continue;
        data['id'] = doc.id;

        // Fetch property details if needed for the PDF/UI
        final propertyId = data['propertyId'];
        if (propertyId != null) {
          final propDoc = await _firestore
              .collection('properties')
              .doc(propertyId)
              .get();
          if (propDoc.exists) {
            final propertyData = propDoc.data()!;
            propertyData['id'] = propDoc.id;
            data['propertyData'] = propertyData;
          }
        }
        visits.add(data);
      }
    } catch (e) {
      Log.e('PropertyService', 'Error fetching user site visits: $e');
    }

    if (visits.isNotEmpty) return visits;

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored =
          jsonDecode(prefs.getString('siteVisits') ?? '{}')
              as Map<String, dynamic>;
      for (final entry in stored.entries) {
        final data = Map<String, dynamic>.from(entry.value as Map);
        data['id'] = entry.key;
        data['propertyId'] = entry.key;
        final dateStr = data['date'] as String?;
        if (dateStr != null) {
          data['date'] = Timestamp.fromDate(
            DateTime.tryParse(dateStr) ?? DateTime.now(),
          );
        }
        final propertyId = entry.key;
        try {
          final propertyDoc = await _firestore
              .collection('properties')
              .doc(propertyId)
              .get();
          if (propertyDoc.exists) {
            final propertyData = propertyDoc.data()!;
            propertyData['id'] = propertyDoc.id;
            data['propertyData'] = propertyData;
          }
        } catch (_) {}
        visits.add(data);
      }
    } catch (_) {}

    return visits;
  }

  Stream<List<Property>> streamPropertiesByCategory(String category) {
    var query = _firestore
        .collection('properties')
        .where('isActive', isEqualTo: true)
        .where('status', whereIn: ['approved', 'available']);

    if (category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      final properties = _processExpiry(
        snapshot.docs.map((doc) {
          final data = doc.data();
          return Property.fromMap(data, doc.id);
        }).toList(),
      );

      properties.sort((a, b) {
        int cmp = b.visibilityScore.compareTo(a.visibilityScore);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });

      return properties;
    });
  }

  Future<List<Property>> searchProperties(String query) async {
    try {
      final snapshot = await _firestore
          .collection('properties')
          .where('isActive', isEqualTo: true)
          .where('status', whereIn: ['approved', 'available'])
          .get();

      final lowerQuery = query.toLowerCase();
      final properties = _processExpiry(
        snapshot.docs
            .where((doc) {
              final data = doc.data();
              final title = (data['title'] ?? '').toLowerCase();
              final location = (data['location'] ?? '').toLowerCase();
              final type = (data['type'] ?? '').toLowerCase();
              final category = (data['category'] ?? '').toLowerCase();

              return title.contains(lowerQuery) ||
                  location.contains(lowerQuery) ||
                  type.contains(lowerQuery) ||
                  category.contains(lowerQuery);
            })
            .map((doc) {
              return Property.fromMap(doc.data(), doc.id);
            })
            .toList(),
      );

      return properties;
    } catch (e) {
      Log.e('PropertyService', 'Error searching properties: $e');
      return [];
    }
  }

  Future<Property?> getPropertyById(String id) async {
    try {
      final doc = await _firestore.collection('properties').doc(id).get();
      if (doc.exists) {
        return Property.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      Log.e('PropertyService', 'Error fetching property: $e');
      return null;
    }
  }

  Stream<List<String>> streamCategories() {
    return _firestore
        .collection('properties')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => (doc.data()['category'] as String?) ?? 'Other')
              .toSet()
              .toList();
          categories.sort();
          return ['All', ...categories];
        });
  }

  Future<List<String>> getCategories() async {
    try {
      final snapshot = await _firestore
          .collection('properties')
          .where('isActive', isEqualTo: true)
          .where('status', whereIn: ['approved', 'available'])
          .get();

      final categories = snapshot.docs
          .map((doc) => (doc.data()['category'] as String?) ?? 'Other')
          .toSet()
          .toList();
      categories.sort();
      return ['All', ...categories];
    } catch (e) {
      Log.e('PropertyService', 'Error fetching categories: $e');
      return ['All'];
    }
  }

  Future<String> addProperty(Property property) async {
    try {
      final docRef = await _firestore
          .collection('properties')
          .add(property.toMap());
      return docRef.id;
    } catch (e) {
      Log.e('PropertyService', 'Error adding property: $e');
      rethrow;
    }
  }

  Future<String> submitSellerProperty(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    final docRef = await _firestore.collection('properties').add({
      'status': 'pending_approval',
      'isActive': false,
      'isFeatured': false,
      'isVerified': false,
      ...data,
      'sellerId': user?.uid,
      'userId': user?.uid,
      'views': 0,
      'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _createNotification(
      title: 'New Property Approval',
      message: '${data['title'] ?? 'Property'} is waiting for approval',
      type: 'property_approval',
      propertyId: docRef.id,
    );
    return docRef.id;
  }

  Future<bool> hasRecentLead(String propertyId, String leadType) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    final snapshot = await _firestore
        .collection('property_leads')
        .where('propertyId', isEqualTo: propertyId)
        .where('buyerId', isEqualTo: user.uid)
        .where('leadType', isEqualTo: leadType)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(yesterday))
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Returns the creation time of the most recent lead sent by the current
  /// user for this property/type, or `null` if none exists. Used to unlock the
  /// "Resend Lead" button after the 24h callback window has passed.
  Future<DateTime?> lastLeadTime(String propertyId, String leadType) async {
    final doc = await _latestLeadDoc(propertyId, leadType);
    if (doc == null) return null;
    final ts = doc.data()['createdAt'];
    return ts is Timestamp ? ts.toDate() : null;
  }

  /// Returns the buyer name/phone saved on the most recent lead for this
  /// property/type, so a resend reuses the contact the user entered instead of
  /// falling back to a generic name.
  Future<({String name, String phone})> lastLeadContact(
    String propertyId,
    String leadType,
  ) async {
    final doc = await _latestLeadDoc(propertyId, leadType);
    if (doc == null) return (name: '', phone: '');
    final data = doc.data();
    return (
      name: (data['buyerName'] as String?) ?? '',
      phone: (data['buyerPhone'] as String?) ?? '',
    );
  }

  Future<QueryDocumentSnapshot?> _latestLeadDoc(
    String propertyId,
    String leadType,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore
        .collection('property_leads')
        .where('propertyId', isEqualTo: propertyId)
        .where('buyerId', isEqualTo: user.uid)
        .where('leadType', isEqualTo: leadType)
        .get();

    QueryDocumentSnapshot? latest;
    for (final doc in snapshot.docs) {
      final ts = doc.data()['createdAt'];
      if (ts is Timestamp) {
        final t = ts.toDate();
        final cur = latest == null
            ? null
            : latest.data()['createdAt'];
        if (cur is! Timestamp || t.isAfter(cur.toDate())) {
          latest = doc;
        }
      }
    }
    return latest;
  }

  Future<String> createLead({
    required Property property,
    required String leadType,
    String buyerName = 'Customer',
    String buyerPhone = '',
    Map<String, dynamic> extra = const {},
  }) async {
    final user = _auth.currentUser;
    final leadRef = _firestore.collection('property_leads').doc();
    final resolvedSellerId = property.sellerId.isNotEmpty
        ? property.sellerId
        : (property.extraDetails['userId'] ??
              property.extraDetails['sellerId'] ??
              '');
    final resolvedBrokerId = (property.extraDetails['brokerId'] as String?)
            ?.isNotEmpty ==
        true
        ? property.extraDetails['brokerId'] as String
        : resolvedSellerId;
    await leadRef.set({
      'leadId': leadRef.id,
      'propertyId': property.id,
      'sellerId': resolvedSellerId,
      'brokerId': resolvedBrokerId,
      'sellerName': property.ownerName.isNotEmpty
          ? property.ownerName
          : property.brokerName,
      'sellerPhone': property.ownerPhone.isNotEmpty
          ? property.ownerPhone
          : property.brokerPhone,
      'propertyTitle': property.title,
      'propertyPrice': property.price,
      'propertyLocation': property.location,
      'buyerId': user?.uid,
      'buyerName': buyerName.trim().isEmpty
          ? (user?.displayName ?? 'Customer')
          : buyerName.trim(),
      'buyerPhone': buyerPhone.trim().isEmpty
          ? (user?.phoneNumber ?? '')
          : buyerPhone.trim(),
      'leadType': leadType,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
      ...extra,
    });
    try {
      await _createNotification(
        title: 'New Real Estate Lead',
        message:
            '${property.title} received a ${leadType.replaceAll('_', ' ')} lead',
        type: 'property_lead',
        propertyId: property.id,
        leadId: leadRef.id,
        brokerId: resolvedSellerId,
      );
    } catch (e) {
      Log.e('PropertyService', 'Lead created but notification failed: $e');
    }
    return leadRef.id;
  }

  Future<String> bookSiteVisit({
    required Property property,
    required String name,
    required String phone,
    required DateTime date,
    required String time,
    required String notes,
    String? razorpayPaymentId,
    String? razorpayOrderId,
    bool skipPayment = false,
  }) async {
    final user = _auth.currentUser;
    final visitRef = _firestore.collection('site_visits').doc();
    final resolvedSellerId = property.sellerId.isNotEmpty
        ? property.sellerId
        : (property.extraDetails['userId'] ??
              property.extraDetails['sellerId'] ??
              '');
    final resolvedBrokerId = (property.extraDetails['brokerId'] as String?)
            ?.isNotEmpty ==
        true
        ? property.extraDetails['brokerId'] as String
        : resolvedSellerId;

    String? paymentId;
    String paymentProvider;
    if (skipPayment) {
      paymentId = 'test_skip_${DateTime.now().millisecondsSinceEpoch}';
      paymentProvider = 'test_skip';
    } else if (razorpayPaymentId != null) {
      paymentId = razorpayPaymentId;
      paymentProvider = 'razorpay';
    } else {
      final payment = await createCashfreePaymentIntent(
        purpose: 'site_visit',
        amount: 99,
        propertyId: property.id,
        metadata: {'visitId': visitRef.id, 'propertyTitle': property.title},
      );
      paymentId = payment['cashfreeOrderId'];
      paymentProvider = 'cashfree';
    }
    final leadId = await createLead(
      property: property,
      leadType: 'site_visit',
      buyerName: name,
      buyerPhone: phone,
      extra: {
        'preferredDate': Timestamp.fromDate(date),
        'preferredTime': time,
        'notes': notes,
        'bookingFee': skipPayment ? 0 : 99,
        'paymentStatus': skipPayment ? 'skipped' : 'paid',
        'paymentProvider': paymentProvider,
        if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
        if (razorpayOrderId != null) 'razorpayOrderId': razorpayOrderId,
        if (razorpayPaymentId == null && !skipPayment)
          'cashfreeOrderId': paymentId,
      },
    );
    await visitRef.set({
      'visitId': visitRef.id,
      'leadId': leadId,
      'propertyId': property.id,
      'sellerId': resolvedSellerId,
      'brokerId': resolvedBrokerId,
      'sellerName': property.ownerName.isNotEmpty
          ? property.ownerName
          : property.brokerName,
      'sellerPhone': property.ownerPhone.isNotEmpty
          ? property.ownerPhone
          : property.brokerPhone,
      'brokerName': property.brokerName,
      'brokerPhone': property.brokerPhone,
      'propertyTitle': property.title,
      'buyerId': user?.uid,
      'buyerName': name.trim(),
      'buyerPhone': phone.trim(),
      'date': Timestamp.fromDate(date),
      'time': time,
      'notes': notes.trim(),
      'bookingFee': skipPayment ? 0 : 99,
      'paymentStatus': skipPayment ? 'skipped' : 'paid',
      'paymentProvider': paymentProvider,
      if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
      if (razorpayOrderId != null) 'razorpayOrderId': razorpayOrderId,
      if (razorpayPaymentId == null && !skipPayment)
        'cashfreeOrderId': paymentId,
      'status': 'confirmed',
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await _createNotification(
        title: 'New Site Visit Booked',
        message: '${property.title} - $name booked for $time',
        type: 'site_visit_booked',
        propertyId: property.id,
        brokerId: resolvedSellerId,
      );
    } catch (e) {
      Log.e('PropertyService', 'Site visit saved but notification failed: $e');
    }

    return visitRef.id;
  }

  Future<String> requestFeaturedProperty({
    required String propertyId,
    required String plan,
    required int amount,
  }) async {
    final user = _auth.currentUser;
    final requestRef = _firestore
        .collection('featured_property_requests')
        .doc();
    final payment = await createCashfreePaymentIntent(
      purpose: 'featured_property',
      amount: amount,
      propertyId: propertyId,
      metadata: {'requestId': requestRef.id, 'plan': plan},
    );
    await requestRef.set({
      'requestId': requestRef.id,
      'propertyId': propertyId,
      'sellerId': user?.uid,
      'featuredPlan': plan,
      'amount': amount,
      'paymentStatus': 'pending',
      'paymentProvider': 'cashfree',
      'cashfreeOrderId': payment['cashfreeOrderId'],
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return requestRef.id;
  }

  Future<String> requestPropertyVerification({
    required String propertyId,
    required List<String> documents,
    required int amount,
  }) async {
    final user = _auth.currentUser;
    final requestRef = _firestore
        .collection('property_verification_requests')
        .doc();
    final payment = await createCashfreePaymentIntent(
      purpose: 'property_verification',
      amount: amount,
      propertyId: propertyId,
      metadata: {'requestId': requestRef.id},
    );
    await requestRef.set({
      'requestId': requestRef.id,
      'propertyId': propertyId,
      'sellerId': user?.uid,
      'documents': documents,
      'amount': amount,
      'paymentStatus': 'pending',
      'paymentProvider': 'cashfree',
      'cashfreeOrderId': payment['cashfreeOrderId'],
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return requestRef.id;
  }

  Future<String> unlockBrokerContact(Property property, String plan) async {
    final user = _auth.currentUser;
    final unlockRef = _firestore.collection('property_contact_unlocks').doc();
    final amount = plan == 'monthly_pass' ? 199 : 29;
    final payment = await createCashfreePaymentIntent(
      purpose: 'contact_unlock',
      amount: amount,
      propertyId: property.id,
      metadata: {'unlockId': unlockRef.id, 'plan': plan},
    );
    await unlockRef.set({
      'unlockId': unlockRef.id,
      'propertyId': property.id,
      'propertyTitle': property.title,
      'buyerId': user?.uid,
      'plan': plan,
      'amount': amount,
      'paymentStatus': 'pending',
      'paymentProvider': 'cashfree',
      'cashfreeOrderId': payment['cashfreeOrderId'],
      'status': 'unlocked',
      'brokerName': property.brokerName,
      'brokerPhone': property.brokerPhone,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await createLead(
      property: property,
      leadType: 'contact_unlock',
      extra: {'unlockId': unlockRef.id, 'unlockPlan': plan},
    );
    return unlockRef.id;
  }

  Future<Map<String, dynamic>> createCashfreePaymentIntent({
    required String purpose,
    required int amount,
    required String propertyId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final user = _auth.currentUser;
    final paymentRef = _firestore.collection('real_estate_payments').doc();
    final cashfreeOrderId = 'CF_RE_${paymentRef.id}';
    final data = {
      'paymentId': paymentRef.id,
      'cashfreeOrderId': cashfreeOrderId,
      'provider': 'cashfree',
      'purpose': purpose,
      'propertyId': propertyId,
      'userId': user?.uid,
      'amount': amount,
      'currency': 'INR',
      'status': 'pending',
      'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await paymentRef.set(data);
    return data;
  }

  Future<void> incrementPropertyView(String propertyId) {
    return _firestore.collection('properties').doc(propertyId).set({
      'views': FieldValue.increment(1),
      'lastViewedAt': FieldValue.serverTimestamp(),
    }, const SetOptions(merge: true));
  }

  Future<bool> hasContactUnlock(String propertyId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final snapshot = await _firestore
        .collection('property_contact_unlocks')
        .where('propertyId', isEqualTo: propertyId)
        .where('buyerId', isEqualTo: user.uid)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final plan = data['plan'] as String?;
      final createdAt = data['createdAt'] as Timestamp?;

      if (plan == 'one_time') return true;

      if (plan == 'monthly_pass' && createdAt != null) {
        final expiry = createdAt.toDate().add(const Duration(days: 30));
        if (DateTime.now().isBefore(expiry)) return true;
      }
    }

    final passActive = await hasActiveMonthlyPass();
    if (passActive) return true;

    return false;
  }

  Future<bool> hasActiveMonthlyPass() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final snapshot = await _firestore
        .collection('property_contact_unlocks')
        .where('buyerId', isEqualTo: user.uid)
        .where('plan', isEqualTo: 'monthly_pass')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return false;

    final createdAt = snapshot.docs.first.data()['createdAt'] as Timestamp?;
    if (createdAt == null) return false;

    final expiry = createdAt.toDate().add(const Duration(days: 30));
    return DateTime.now().isBefore(expiry);
  }

  Future<void> saveContactUnlock({
    required Property property,
    required String plan,
    required String paymentId,
    String? orderId,
  }) async {
    final user = _auth.currentUser;
    final unlockRef = _firestore.collection('property_contact_unlocks').doc();
    final amount = plan == 'monthly_pass' ? 199 : 29;

    await unlockRef.set({
      'unlockId': unlockRef.id,
      'propertyId': property.id,
      'propertyTitle': property.title,
      'buyerId': user?.uid,
      'plan': plan,
      'amount': amount,
      'paymentStatus': 'paid',
      'paymentProvider': 'razorpay',
      'razorpayPaymentId': paymentId,
      if (orderId != null) 'razorpayOrderId': orderId,
      'status': 'unlocked',
      'brokerName': property.brokerName,
      'brokerPhone': property.brokerPhone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createNotification({
    required String title,
    required String message,
    required String type,
    String? propertyId,
    String? leadId,
    String? brokerId,
  }) {
    return _firestore.collection('notifications').add({
      'title': title,
      'message': message,
      'type': type,
      'propertyId': propertyId,
      'leadId': leadId,
      'userId': brokerId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProperty(String id, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('properties').doc(id).update(updates);
    } catch (e) {
      Log.e('PropertyService', 'Error updating property: $e');
      rethrow;
    }
  }

  Future<void> deleteProperty(String id) async {
    try {
      await _firestore.collection('properties').doc(id).update({
        'isActive': false,
      });
    } catch (e) {
      Log.e('PropertyService', 'Error deleting property: $e');
      rethrow;
    }
  }

  /// Marks a property as sold and removes the listing entirely.
  Future<void> markAsSoldAndDelete(String id) async {
    await _firestore.collection('properties').doc(id).update({
      'status': 'sold',
      'isActive': false,
    });
    await _firestore.collection('properties').doc(id).delete();
  }

  Future<int> getActivePropertiesCount() async {
    try {
      final snapshot = await _firestore
          .collection('properties')
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      Log.e('PropertyService', 'Error counting properties: $e');
      return 0;
    }
  }

  Future<void> bookSlot(String dateStr, String time, String propertyId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore.collection('property_contact_unlocks').add({
        'type': 'slot_booking',
        'date': dateStr,
        'time': time,
        'propertyId': propertyId,
        'buyerId': user.uid,
        'buyerName': user.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<Set<String>> getBookedSlotKeys(String dateStr) async {
    try {
      final snapshot = await _firestore
          .collection('property_contact_unlocks')
          .where('type', isEqualTo: 'slot_booking')
          .where('date', isEqualTo: dateStr)
          .get();
      return snapshot.docs
          .map((d) => (d.data()['time'] as String?) ?? '')
          .where((t) => t.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }
}
