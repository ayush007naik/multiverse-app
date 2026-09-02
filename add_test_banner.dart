// Run this script to add a test banner to Firestore
// Usage: firebase firestore:import or run via Firebase Console

import 'package:db_compat/db_compat.dart';

Future<void> addTestBanner() async {
  final firestore = FirebaseFirestore.instance;
  
  // Banner 1 - Welcome Banner
  await firestore.collection('banners').add({
    'imageUrl': '', // Add your banner image URL here
    'title': 'WELCOME TO MULTIVERSE',
    'subtitle': 'Your One-Stop Marketplace',
    'actionUrl': '',
    'isActive': true,
    'priority': 1,
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  print('✅ Test banner added successfully!');
  print('📱 Open the app to see the banner');
  print('🔥 Update imageUrl with your Firebase Storage URL');
}

// Run this function to add multiple test banners
Future<void> addMultipleTestBanners() async {
  final firestore = FirebaseFirestore.instance;
  
  final banners = [
    {
      'imageUrl': '',
      'title': 'MEGA SALE',
      'subtitle': 'Up to 50% OFF',
      'actionUrl': '',
      'isActive': true,
      'priority': 1,
    },
    {
      'imageUrl': '',
      'title': 'NEW ARRIVALS',
      'subtitle': 'Check out latest products',
      'actionUrl': '',
      'isActive': true,
      'priority': 2,
    },
    {
      'imageUrl': '',
      'title': 'MOVIE BOOKING',
      'subtitle': 'Book tickets now!',
      'actionUrl': '/movies',
      'isActive': true,
      'priority': 3,
    },
  ];
  
  for (final banner in banners) {
    await firestore.collection('banners').add({
      ...banner,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  print('✅ ${banners.length} test banners added!');
}
