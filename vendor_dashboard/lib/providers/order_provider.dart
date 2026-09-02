import 'package:flutter/material.dart';
import 'package:db_compat/db_compat.dart';

class OrderProvider extends ChangeNotifier {
  Stream<QuerySnapshot> streamVendorOrdersByStatus(String vendorId, List<String> statuses) {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: vendorId)
        .where('status', whereIn: statuses)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
  
  Stream<QuerySnapshot> streamVendorOrders(String vendorId) {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Listen for new pending orders (for popup)
  Stream<QuerySnapshot> streamNewPendingOrders(String vendorId) {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: vendorId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
