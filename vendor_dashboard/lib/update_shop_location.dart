import 'package:db_compat/db_compat.dart';

/// Utility to update GPS coordinates for existing shops
/// Run this to fix shops that have 0.0, 0.0 coordinates
/// 
/// USAGE:
/// 1. Find your Vendor ID from Firebase Console (vendors collection)
/// 2. Update the VENDOR_ID, LATITUDE, and LONGITUDE constants below
/// 3. Run this script from main() or call the function

// ===== UPDATE THESE VALUES =====
const String VENDOR_ID = 'YOUR_VENDOR_ID_HERE'; // Replace with your actual vendor ID
const double LATITUDE = 31.6171822;  // Your shop's latitude
const double LONGITUDE = 76.9000305; // Your shop's longitude
// ================================

Future<void> updateShopLocation() async {
  try {
    print('🔄 Updating shop location...');
    print('📍 Vendor ID: $VENDOR_ID');
    print('📍 Latitude: $LATITUDE');
    print('📍 Longitude: $LONGITUDE');

    // Update shops collection
    await FirebaseFirestore.instance.collection('shops').doc(VENDOR_ID).update({
      'lat': LATITUDE,
      'lng': LONGITUDE,
      'location': {
        'latitude': LATITUDE,
        'longitude': LONGITUDE,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Shop location updated successfully!');
    print('🎉 Your shop GPS coordinates are now set to:');
    print('   Latitude: $LATITUDE');
    print('   Longitude: $LONGITUDE');
    print('');
    print('📱 Customers will now see accurate distance calculations!');
  } catch (e) {
    print('❌ Failed to update shop location: $e');
    print('');
    print('Troubleshooting:');
    print('1. Check if Vendor ID is correct');
    print('2. Make sure Firebase is initialized');
    print('3. Check Firestore security rules');
  }
}

/// Update multiple shops at once
Future<void> updateMultipleShops(Map<String, Map<String, double>> shops) async {
  print('🔄 Updating ${shops.length} shops...');
  
  for (final entry in shops.entries) {
    final vendorId = entry.key;
    final lat = entry.value['latitude']!;
    final lng = entry.value['longitude']!;
    
    try {
      await FirebaseFirestore.instance.collection('shops').doc(vendorId).update({
        'lat': lat,
        'lng': lng,
        'location': {
          'latitude': lat,
          'longitude': lng,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Updated vendor: $vendorId -> ($lat, $lng)');
    } catch (e) {
      print('❌ Failed to update vendor $vendorId: $e');
    }
  }
  
  print('✅ Batch update complete!');
}

// Example usage in main():
// void main() async {
//   // Initialize Firebase first
//   await Firebase.initializeApp();
//   
//   // Update single shop
//   await updateShopLocation();
//   
//   // OR update multiple shops
//   // await updateMultipleShops({
//   //   'vendor_id_1': {'latitude': 31.6171822, 'longitude': 76.9000305},
//   //   'vendor_id_2': {'latitude': 19.0760, 'longitude': 72.8777},
//   // });
// }
