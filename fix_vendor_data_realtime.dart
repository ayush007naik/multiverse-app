import 'package:db_compat/db_compat.dart';
/// Script to sync missing ownerName and location in 'shops' collection from 'vendors' collection
Future<void> syncVendorDataToShops() async {
  print('🔄 Starting Real-time Vendor Data Sync...');
  
  final firestore = FirebaseFirestore.instance;
  
  try {
    // 1. Get all vendors
    final vendorsSnapshot = await firestore.collection('vendors').get();
    print('📊 Found ${vendorsSnapshot.docs.length} vendors');
    
    int totalSynced = 0;
    
    for (var vendorDoc in vendorsSnapshot.docs) {
      final vendorData = vendorDoc.data();
      final vendorId = vendorDoc.id;
      final ownerName = vendorData['ownerName'];
      final location = vendorData['location'];
      
      // 2. Check if shop document exists for this vendor
      final shopRef = firestore.collection('shops').doc(vendorId);
      final shopDoc = await shopRef.get();
      
      if (shopDoc.exists) {
        final shopData = shopDoc.data()!;
        Map<String, dynamic> updates = {};
        
        // Sync ownerName
        if (shopData['ownerName'] == null && ownerName != null) {
          updates['ownerName'] = ownerName;
        }
        
        // Sync location/locationLabel
        if (shopData['locationLabel'] == null && location != null) {
          updates['locationLabel'] = location is String ? location : (location is Map ? location['label'] : null);
        }
        
        if (updates.isNotEmpty) {
          print('   ✅ Syncing data for shop: ${shopData['name'] ?? vendorData['shopName']} ($vendorId)');
          await shopRef.update(updates);
          totalSynced++;
        }
      }
    }
    
    print('\n✨ Sync Complete! Total shops updated: $totalSynced');
    
  } catch (e) {
    print('❌ Error during sync: $e');
  }
}

void main() async {
  // This script is intended to be used in a Flutter environment or via a tool that has Firebase initialized.
  await syncVendorDataToShops();
}
