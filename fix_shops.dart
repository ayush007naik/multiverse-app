import 'package:db_compat/db_compat.dart';

/// Run this script to fix existing vendor shops
/// Adds missing 'id' field and activates shops
/// 
/// Usage: dart fix_shops.dart
void main() async {
  print('🔧 Fixing vendor shops...\n');
  
  // Initialize Firebase (make sure you have firebase_options.dart)
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );
  
  final firestore = FirebaseFirestore.instance;
  
  try {
    // Get all shops
    final shopsSnapshot = await firestore.collection('shops').get();
    
    print('📊 Found ${shopsSnapshot.docs.length} shops\n');
    
    int fixed = 0;
    int alreadyOk = 0;
    
    for (final doc in shopsSnapshot.docs) {
      final data = doc.data();
      final shopId = doc.id;
      
      print('🔍 Checking shop: ${data['name'] ?? 'Unknown'} ($shopId)');
      
      bool needsUpdate = false;
      Map<String, dynamic> updates = {};
      
      // Check if 'id' field exists
      if (data['id'] == null || data['id'] != shopId) {
        updates['id'] = shopId;
        needsUpdate = true;
        print('   ❌ Missing id field');
      } else {
        print('   ✅ id field exists');
      }
      
      // Check if isActive is false (needs activation)
      if (data['isActive'] == false) {
        print('   ⚠️  Shop is inactive (isActive: false)');
        print('   💡 Run admin approval to activate');
      } else if (data['isActive'] == true) {
        print('   ✅ Shop is active');
      }
      
      // Check delivery status
      if (data['isDelivering'] == null) {
        updates['isDelivering'] = false;
        updates['deliveryStatus'] = 'not_delivering';
        needsUpdate = true;
        print('   ❌ Missing delivery status');
      } else {
        print('   ✅ Delivery status set');
      }
      
      // Update if needed
      if (needsUpdate) {
        print('   🔄 Updating shop...');
        await doc.reference.update(updates);
        fixed++;
        print('   ✅ Updated!\n');
      } else {
        alreadyOk++;
        print('   ✅ Already OK\n');
      }
    }
    
    print('\n${'='*50}');
    print('📊 SUMMARY:');
    print('   Total shops: ${shopsSnapshot.docs.length}');
    print('   Fixed: $fixed');
    print('   Already OK: $alreadyOk');
    print('='*50);
    
  } catch (e) {
    print('\n❌ Error: $e');
  }
}
