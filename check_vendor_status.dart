import 'package:db_compat/db_compat.dart';

// Run this script to check and fix vendor shop status
void main() async {
  print('🔍 Checking vendor shop status...\n');
  
  // Get all vendors
  final vendorsSnapshot = await FirebaseFirestore.instance.collection('vendors').get();
  
  print('📊 Found ${vendorsSnapshot.docs.length} vendors\n');
  
  for (final vendorDoc in vendorsSnapshot.docs) {
    final vendorData = vendorDoc.data();
    final shopName = vendorData['shopName'] ?? 'Unknown';
    final isShopOpen = vendorData['isShopOpen'] ?? false;
    final status = vendorData['status'] ?? 'unknown';
    
    print('🏪 Vendor: $shopName');
    print('   ID: ${vendorDoc.id}');
    print('   Status: $status');
    print('   Shop Open: ${isShopOpen ? "✅ YES" : "❌ NO"}');
    print('');
    
    // If shop is closed, you can uncomment this to open it:
    // if (!isShopOpen) {
    //   await FirebaseFirestore.instance.collection('vendors').doc(vendorDoc.id).update({
    //     'isShopOpen': true,
    //   });
    //   print('   ✅ Auto-opened shop!');
    // }
    
    print('---');
  }
  
  print('\n✅ Check complete!');
}
