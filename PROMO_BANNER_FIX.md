# 🔥 PROMO BANNER FIX - Complete Guide

## ✅ What Was Fixed

### Found the Root Cause!
The old banners were hardcoded in **`lib/services/branding_service.dart`** which creates default offers in Firebase.

### Changes Made

**File: `lib/services/branding_service.dart`**

#### ❌ REMOVED:
1. ~~"50% OFF - First order from any shop"~~
2. ~~"₹100 Cashback - Pay via UPI today"~~

#### ✅ ADDED:
**Banner 1:**
```dart
{
  'title': '60% OFF on Select Shops',
  'sub': 'Limited time deals on top stores',
  'color1': '0xFFFF5722',      // Orange
  'color2': '0xFFFF2E00',      // Red-Orange
  'tag': '🔥 Trending',        // NEW!
  'isActive': true,
}
```

**Banner 2:**
```dart
{
  'title': 'FREE Delivery',
  'sub': 'Orders above ₹699',
  'color1': '0xFF6200EA',      // Purple
  'color2': '0xFF2196F3',      // Blue
  'isActive': true,
}
```

---

## 🚀 NEXT STEPS (IMPORTANT!)

Since Firebase already has the old offers saved, you need to **clear them** or they'll keep showing.

### Option 1: Clear Firebase Data (RECOMMENDED)

1. Go to **Firebase Console**
2. Navigate to **Firestore Database**
3. Find collection: `branding/offers`
4. **Delete all documents** in the offers collection
5. The app will recreate them with new data on next launch

### Option 2: Manual Update via Code

Add this temporary code to clear old offers:

```dart
// Add this to a button or run once
Future<void> clearOldOffers() async {
  final brandingDoc = FirebaseFirestore.instance
      .collection('branding')
      .doc('default');
  
  final offersSnapshot = await brandingDoc.collection('offers').get();
  
  for (var doc in offersSnapshot.docs) {
    await doc.reference.delete();
  }
  
  print('Old offers deleted! Restart app to create new ones.');
}
```

### Option 3: Hot Restart (Quick Test)

1. **Stop** the running app
2. Run:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```
3. Press **`R`** (Hot Restart, NOT `r`)

---

## 🔍 Why This Happened

The issue was:
1. **First launch**: BrandingService created old offers in Firebase
2. **Code updated**: But Firebase already had data
3. **Code logic**: Only creates offers if collection is EMPTY
4. **Result**: Old offers kept showing from Firebase cache

```dart
if (offersSnapshot.docs.isEmpty) {
  // Only runs if Firebase is empty!
  // If data exists, old offers stay
}
```

---

## ✅ Verification Checklist

After clearing Firebase and restarting:

- [ ] Old "50% OFF" banner is GONE
- [ ] Old "₹100 Cashback" banner is GONE
- [ ] New "60% OFF on Select Shops" banner appears
- [ ] "🔥 Trending" tag is visible on first banner
- [ ] "FREE Delivery" shows "Orders above ₹699"
- [ ] Orange/Red gradient on first banner
- [ ] Purple/Blue gradient on second banner
- [ ] Only 2 banners showing (not 3)

---

## 🎨 Final Result

**Banner 1 (Trending):**
```
┌────────────────────────────┐
│  🔥 Trending               │
│                            │
│  60% OFF on Select Shops   │
│  Limited time deals on     │
│  top stores                │
└────────────────────────────┘
   Orange → Red Gradient
```

**Banner 2 (Delivery):**
```
┌────────────────────────────┐
│                            │
│  FREE Delivery             │
│  Orders above ₹699         │
│                            │
└────────────────────────────┘
   Purple → Blue Gradient
```

---

## 🐛 Still Not Working?

### If old banners STILL show:

1. **Delete app from emulator/device**
2. **Uninstall completely**
3. Run:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```
4. Fresh install will create new Firebase data

### Force Update (Nuclear Option):

```dart
// In branding_service.dart, temporarily add:
Future<void> forceUpdateOffers() async {
  final brandingDoc = FirebaseFirestore.instance
      .collection('branding')
      .doc('default');
  
  // Delete all old offers
  final offersSnapshot = await brandingDoc.collection('offers').get();
  for (var doc in offersSnapshot.docs) {
    await doc.reference.delete();
  }
  
  // Recreate with new data
  await initializeBranding();
}
```

---

## 📝 Files Modified

1. ✅ `lib/services/branding_service.dart` - Updated default offers
2. ✅ `lib/screen/home_screen.dart` - Updated local fallback offers + tag support

---

**Date**: April 24, 2026  
**Status**: ✅ Code Updated  
**Action Required**: Clear Firebase offers collection + Hot Restart
