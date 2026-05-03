import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Quick Test Script for Firestore Status Updates
/// Run this to verify your Firestore setup is working
class FirestoreStatusUpdateTest {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Test 1: Verify Firebase is connected
  Future<bool> testFirebaseConnection() async {
    try {
      debugPrint('🧪 TEST 1: Testing Firebase connection...');
      
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ Not logged in!');
        return false;
      }
      
      debugPrint('✅ Logged in as: ${user.uid}');
      
      // Try to read from orders collection
      final snapshot = await _firestore.collection('orders').limit(1).get();
      debugPrint('✅ Can read orders collection');
      
      return true;
    } catch (e) {
      debugPrint('❌ Firebase connection failed: $e');
      return false;
    }
  }

  /// Test 2: Find orders assigned to current rider
  Future<void> testRiderOrders() async {
    try {
      debugPrint('🧪 TEST 2: Finding rider orders...');
      
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ Not logged in!');
        return;
      }
      
      final snapshot = await _firestore
          .collection('orders')
          .where('assignedRiderId', isEqualTo: user.uid)
          .get();
      
      debugPrint('✅ Found ${snapshot.docs.length} orders for rider');
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        debugPrint('   📦 Order ID: ${doc.id}');
        debugPrint('   📦 Status: ${data['status']}');
        debugPrint('   📦 Customer: ${data['customerName']}');
      }
    } catch (e) {
      debugPrint('❌ Error finding rider orders: $e');
    }
  }

  /// Test 3: Update order status
  Future<bool> testStatusUpdate(String orderId, String newStatus) async {
    try {
      debugPrint('🧪 TEST 3: Testing status update...');
      debugPrint('   Order ID: $orderId');
      debugPrint('   New Status: $newStatus');
      
      // Verify order exists
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        debugPrint('❌ Order does not exist!');
        return false;
      }
      
      final currentStatus = orderDoc.data()?['status'];
      debugPrint('   Current Status: $currentStatus');
      
      // Update status
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Update sent to Firestore');
      
      // Verify update
      final updatedDoc = await _firestore.collection('orders').doc(orderId).get();
      final updatedStatus = updatedDoc.data()?['status'];
      
      if (updatedStatus == newStatus) {
        debugPrint('✅ Status verified: $updatedStatus');
        return true;
      } else {
        debugPrint('❌ Status mismatch! Expected: $newStatus, Got: $updatedStatus');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Status update failed: $e');
      return false;
    }
  }

  /// Test 4: Test complete status flow
  Future<void> testCompleteFlow(String orderId) async {
    debugPrint('🧪 TEST 4: Testing complete status flow...');
    
    final flow = ['accepted', 'picked', 'on_the_way', 'delivered'];
    
    for (final status in flow) {
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Testing status: $status');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      final success = await testStatusUpdate(orderId, status);
      
      if (!success) {
        debugPrint('❌ Test failed at status: $status');
        return;
      }
      
      // Wait a moment for Firestore to sync
      await Future.delayed(const Duration(seconds: 2));
    }
    
    debugPrint('\n✅ All status updates successful!');
  }

  /// Test 5: Check Firestore security rules
  Future<void> testSecurityRules() async {
    try {
      debugPrint('🧪 TEST 5: Testing Firestore security rules...');
      
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ Not logged in!');
        return;
      }
      
      // Try to create a test document
      final testDoc = _firestore.collection('orders').doc('test_permissions');
      await testDoc.set({
        'status': 'test',
        'testBy': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Can write to orders collection');
      
      // Try to update
      await testDoc.update({
        'status': 'test_updated',
      });
      
      debugPrint('✅ Can update orders collection');
      
      // Try to read
      final doc = await testDoc.get();
      debugPrint('✅ Can read orders collection');
      
      // Clean up
      await testDoc.delete();
      debugPrint('✅ Can delete from orders collection');
      debugPrint('✅ All security rules passed!');
    } catch (e) {
      debugPrint('❌ Security rules test failed: $e');
    }
  }

  /// Run all tests
  Future<void> runAllTests(String? testOrderId) async {
    debugPrint('\n');
    debugPrint('╔════════════════════════════════════════╗');
    debugPrint('║   FIRESTORE STATUS UPDATE TEST SUITE  ║');
    debugPrint('╚════════════════════════════════════════╝');
    debugPrint('');
    
    // Test 1: Connection
    final connected = await testFirebaseConnection();
    if (!connected) {
      debugPrint('❌ Tests aborted - Firebase not connected');
      return;
    }
    
    // Test 2: Rider orders
    await testRiderOrders();
    
    // Test 3: Security rules
    await testSecurityRules();
    
    // Test 4: Status update (if order ID provided)
    if (testOrderId != null) {
      await testCompleteFlow(testOrderId);
    } else {
      debugPrint('⏭️  Test 4 skipped - No order ID provided');
      debugPrint('   To test status updates, call:');
      debugPrint('   testStatusUpdate("YOUR_ORDER_ID", "picked")');
    }
    
    debugPrint('\n');
    debugPrint('╔════════════════════════════════════════╗');
    debugPrint('║          ALL TESTS COMPLETE           ║');
    debugPrint('╚════════════════════════════════════════╝');
  }
}

/// Usage Example:
/// 
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp();
///   
///   final tester = FirestoreStatusUpdateTest();
///   
///   // Run all tests (replace with your order ID)
///   await tester.runAllTests('your_order_id_here');
///   
///   // Or test individual functions:
///   // await tester.testFirebaseConnection();
///   // await tester.testRiderOrders();
///   // await tester.testStatusUpdate('order_id', 'picked');
///   
///   runApp(MyApp());
/// }
