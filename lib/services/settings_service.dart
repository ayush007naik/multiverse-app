import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsService {
  SettingsService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String paymentTypeUpi = 'upi';
  static const String paymentTypeCard = 'card';

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('User must be logged in');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _addressCollection =>
      _firestore.collection('users').doc(_uid).collection('addresses');

  CollectionReference<Map<String, dynamic>> get _paymentMethodsCollection =>
      _firestore.collection('users').doc(_uid).collection('payment_methods');

  Stream<List<Map<String, dynamic>>> streamAddresses() {
    return _addressCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList(),
        );
  }

  Future<Map<String, dynamic>?> getDefaultAddress() async {
    final defaultSnapshot = await _addressCollection
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();
    if (defaultSnapshot.docs.isNotEmpty) {
      final doc = defaultSnapshot.docs.first;
      return {...doc.data(), 'id': doc.id};
    }

    final fallbackSnapshot = await _addressCollection.limit(1).get();
    if (fallbackSnapshot.docs.isEmpty) return null;
    final doc = fallbackSnapshot.docs.first;
    return {...doc.data(), 'id': doc.id};
  }

  Future<Map<String, dynamic>> addAddress(
    Map<String, dynamic> addressData,
  ) async {
    final existing = await _addressCollection.limit(1).get();
    final shouldBeDefault =
        (addressData['isDefault'] as bool?) ?? existing.docs.isEmpty;

    final doc = _addressCollection.doc();
    final payload = {
      ...addressData,
      'isDefault': shouldBeDefault,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    if (shouldBeDefault) {
      for (final existingDoc in existing.docs) {
        batch.update(existingDoc.reference, {
          'isDefault': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    batch.set(doc, payload);
    await batch.commit();

    return {...payload, 'id': doc.id};
  }

  Future<void> selectAddress(String addressId) async {
    final snapshot = await _addressCollection.get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isDefault': doc.id == addressId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> deleteAddress(String addressId) async {
    final docRef = _addressCollection.doc(addressId);
    final doc = await docRef.get();
    final wasDefault = doc.data()?['isDefault'] == true;
    await docRef.delete();

    if (!wasDefault) return;
    final remaining = await _addressCollection.limit(1).get();
    if (remaining.docs.isEmpty) return;
    await remaining.docs.first.reference.update({
      'isDefault': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamPaymentMethods() {
    return _paymentMethodsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => normalizePaymentMethod({...doc.data(), 'id': doc.id}),
              )
              .toList(),
        );
  }

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final snapshot = await _paymentMethodsCollection
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => normalizePaymentMethod({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<Map<String, dynamic>?> getDefaultPaymentMethod() async {
    final defaultSnapshot = await _paymentMethodsCollection
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();
    if (defaultSnapshot.docs.isNotEmpty) {
      final doc = defaultSnapshot.docs.first;
      return normalizePaymentMethod({...doc.data(), 'id': doc.id});
    }

    final fallbackSnapshot = await _paymentMethodsCollection.limit(1).get();
    if (fallbackSnapshot.docs.isEmpty) return null;
    final doc = fallbackSnapshot.docs.first;
    return normalizePaymentMethod({...doc.data(), 'id': doc.id});
  }

  Future<Map<String, dynamic>> addUpiMethod({
    required String upiId,
    String? providerLabel,
  }) async {
    final normalizedUpiId = upiId.trim().toLowerCase();
    if (!_isValidUpiId(normalizedUpiId)) {
      throw ArgumentError('Enter a valid UPI ID');
    }

    return _addPaymentMethod({
      'type': paymentTypeUpi,
      'upiId': normalizedUpiId,
      'providerLabel': providerLabel?.trim(),
      'displayLabel': normalizedUpiId,
    });
  }

  Future<Map<String, dynamic>> addCardMethod({
    required String cardholderName,
    required String last4Digits,
    String? brand,
  }) async {
    final maskedLast4 = last4Digits.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(maskedLast4)) {
      throw ArgumentError('Only the last 4 card digits are allowed');
    }

    return _addPaymentMethod({
      'type': paymentTypeCard,
      'cardholderName': cardholderName.trim(),
      'last4': maskedLast4,
      'brand': brand?.trim(),
      'displayLabel': _maskedCardLabel(maskedLast4, brand: brand),
    });
  }

  Future<Map<String, dynamic>> _addPaymentMethod(
    Map<String, dynamic> methodData,
  ) async {
    final existing = await _paymentMethodsCollection.limit(1).get();
    final shouldBeDefault = existing.docs.isEmpty;
    final doc = _paymentMethodsCollection.doc();
    final payload = {
      ...methodData,
      'isDefault': shouldBeDefault,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    if (shouldBeDefault) {
      for (final existingDoc in existing.docs) {
        batch.update(existingDoc.reference, {
          'isDefault': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    batch.set(doc, payload);
    await batch.commit();

    return normalizePaymentMethod({...payload, 'id': doc.id});
  }

  Future<void> selectPaymentMethod(String paymentMethodId) async {
    final snapshot = await _paymentMethodsCollection.get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isDefault': doc.id == paymentMethodId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> deletePaymentMethod(String paymentMethodId) async {
    final docRef = _paymentMethodsCollection.doc(paymentMethodId);
    final doc = await docRef.get();
    final wasDefault = doc.data()?['isDefault'] == true;
    await docRef.delete();

    if (!wasDefault) return;
    final remaining = await _paymentMethodsCollection.limit(1).get();
    if (remaining.docs.isEmpty) return;
    await remaining.docs.first.reference.update({
      'isDefault': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Map<String, dynamic> normalizePaymentMethod(
    Map<String, dynamic> data,
  ) {
    final type = (data['type'] as String? ?? paymentTypeUpi).trim();
    final isCard = type == paymentTypeCard;
    final last4 = data['last4'] as String?;
    final upiId = data['upiId'] as String?;
    final brand = data['brand'] as String?;

    return {
      ...data,
      'type': isCard ? paymentTypeCard : paymentTypeUpi,
      'displayLabel':
          data['displayLabel'] as String? ??
          (isCard
              ? _maskedCardLabel(last4 ?? '0000', brand: brand)
              : (upiId ?? 'UPI ID')),
      'paymentSummary': paymentMethodLabel({...data, 'type': type}),
    };
  }

  static String paymentMethodLabel(Map<String, dynamic> method) {
    final type = method['type'] as String? ?? paymentTypeUpi;
    if (type == paymentTypeCard) {
      final brand = (method['brand'] as String?)?.trim();
      final last4 = method['last4'] as String? ?? '0000';
      return _maskedCardLabel(last4, brand: brand);
    }

    final providerLabel = (method['providerLabel'] as String?)?.trim();
    final upiId =
        method['upiId'] as String? ??
        method['displayLabel'] as String? ??
        'UPI ID';
    if (providerLabel != null && providerLabel.isNotEmpty) {
      return '$providerLabel · $upiId';
    }
    return 'UPI · $upiId';
  }

  static String _maskedCardLabel(String last4, {String? brand}) {
    final normalizedBrand = (brand ?? 'Card').trim();
    return '$normalizedBrand ending in $last4';
  }

  static bool _isValidUpiId(String value) {
    return RegExp(r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,}$').hasMatch(value);
  }
}
