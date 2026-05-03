import 'package:cloud_firestore/cloud_firestore.dart';

class WalletService {
  WalletService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> walletRef(String userId) {
    return _db.collection('wallets').doc(userId);
  }

  CollectionReference<Map<String, dynamic>> transactionsRef(String userId) {
    return walletRef(userId).collection('transactions');
  }

  Future<void> ensureWallet(String userId, {String ownerType = 'user'}) async {
    await walletRef(userId).set({
      'userId': userId,
      'ownerType': ownerType,
      'balance': FieldValue.increment(0),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> credit({
    required String userId,
    required double amount,
    required String source,
    String ownerType = 'user',
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    if (amount <= 0) return;
    await _db.runTransaction((transaction) async {
      transaction.set(walletRef(userId), {
        'userId': userId,
        'ownerType': ownerType,
        'balance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(transactionsRef(userId).doc(), {
        'type': 'credit',
        'amount': amount,
        'source': source,
        'description': description ?? source,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> debit({
    required String userId,
    required double amount,
    required String source,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    if (amount <= 0) return;
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(walletRef(userId));
      final balance = (snapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      if (balance < amount) {
        throw Exception('insufficient_wallet_balance');
      }

      transaction.set(walletRef(userId), {
        'balance': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(transactionsRef(userId).doc(), {
        'type': 'debit',
        'amount': amount,
        'source': source,
        'description': description ?? source,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String> requestPayout({
    required String vendorId,
    required double amount,
    String? method,
  }) async {
    if (amount <= 0) {
      throw Exception('invalid_payout_amount');
    }

    final walletSnapshot = await walletRef(vendorId).get();
    final balance =
        (walletSnapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
    if (balance < amount) {
      throw Exception('insufficient_wallet_balance');
    }

    final ref = await _db.collection('payout_requests').add({
      'vendorId': vendorId,
      'amount': amount,
      'method': method ?? 'bank_transfer',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updatePayoutStatus({
    required String requestId,
    required String status,
    required String adminId,
  }) async {
    if (status == 'approved') {
      await _approvePayout(requestId, adminId);
      return;
    }

    await _db.collection('payout_requests').doc(requestId).update({
      'status': status,
      'adminId': adminId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _approvePayout(String requestId, String adminId) async {
    final payoutRef = _db.collection('payout_requests').doc(requestId);
    await _db.runTransaction((transaction) async {
      final payoutSnapshot = await transaction.get(payoutRef);
      final payout = payoutSnapshot.data();
      if (payout == null) throw Exception('payout_not_found');
      if (payout['status'] != 'pending') return;

      final vendorId = payout['vendorId'] as String;
      final amount = (payout['amount'] as num).toDouble();
      final vendorWalletRef = walletRef(vendorId);
      final walletSnapshot = await transaction.get(vendorWalletRef);
      final balance =
          (walletSnapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      if (balance < amount) {
        throw Exception('insufficient_wallet_balance');
      }

      transaction.set(vendorWalletRef, {
        'balance': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(transactionsRef(vendorId).doc(), {
        'type': 'debit',
        'amount': amount,
        'source': 'vendor_payout',
        'description': 'Payout approved',
        'metadata': {'payoutRequestId': requestId},
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(payoutRef, {
        'status': 'approved',
        'adminId': adminId,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
