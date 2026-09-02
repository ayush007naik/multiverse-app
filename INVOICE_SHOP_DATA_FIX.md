# ✅ Invoice PDF - Real Shop Data Fix

## Problem:
Invoice PDF showing:
- ✅ Shop Name (correct)
- ❌ Random GST number (22AAAAA0000A1Z5)
- ❌ Random address (Mandi, Himachal Pradesh)
- ❌ Random phone (+91 7018741456)

## Root Cause:
Shop document in Firestore **doesn't save** phone number and GST number during vendor signup.

## Solution Applied:

### 1. Updated HTML Invoice Service ✅
File: `lib/services/html_invoice_service.dart`

Changed from random fallbacks to real data with N/A fallback:

```dart
// GST - Get from shopData or show N/A (no more random GST)
final gstin = shopData?['gstNumber']?.toString() ?? 
              shopData?['gstin']?.toString() ?? 
              orderData['gstNumber']?.toString() ?? 
              'N/A';  // ← Changed from '22AAAAA0000A1Z5'

// Address - Get from shop location fields
String storeAddress;
if (shopData?['locationLabel'] != null) {
  storeAddress = shopData['locationLabel'];  // ← Real address from Firestore
} else {
  storeAddress = 'N/A';  // ← Changed from 'Mandi, Himachal Pradesh'
}

// Phone - Get from shop or vendor
final storePhone = shopData?['phone']?.toString() ?? 
                   shopData?['contact']?.toString() ?? 
                   orderData['vendorPhone']?.toString() ?? 
                   'N/A';  // ← Changed from '+91 7018741456'
```

### 2. Shop Document Needs Phone & GST ⚠️
File: `vendor_dashboard/lib/services/vendor_service.dart`

**This change needs to be applied manually** (user reverted it):

Add these 2 lines to the shop document creation at line 129:

```dart
await _firestore.collection('shops').doc(uid).set({
  'id': uid,
  'ownerId': uid,
  'name': shopName,
  'category': category,
  'image': shopDisplayImage,
  'phone': phone,         // ← ADD THIS LINE
  'gstNumber': gstNumber, // ← ADD THIS LINE
  'locationLabel': location,
  // ... rest of fields
});
```

## What Happens Now:

### For NEW Vendors (after applying fix):
1. Vendor signs up with phone & GST
2. Shop document saves phone & gstNumber fields
3. Invoice PDF reads these fields from Firestore
4. PDF shows REAL data, not random fallbacks

### For EXISTING Vendors:
Their shop documents don't have phone/gstNumber yet. They need to:
1. Update their shop profile in vendor dashboard
2. Or manually add fields in Firebase Console

## Manual Fix for Existing Shops (Firebase Console):

For each existing shop in Firestore `shops` collection:

```javascript
{
  "phone": "+91 XXXXXXXXXX",       // Add vendor's phone
  "gstNumber": "XXXXXXXXXXXXXXX"   // Add vendor's GST (if available)
}
```

## Testing:

1. **Create new vendor account** with phone and GST number
2. **Place an order** from customer app
3. **Generate invoice PDF**
4. **Check PDF** - Should show:
   - ✅ Real shop name
   - ✅ Real GST number (or N/A if not provided)
   - ✅ Real location from shop
   - ✅ Real phone number

## Files Modified:

1. ✅ `lib/services/html_invoice_service.dart` - Changed fallback from random to N/A
2. ⚠️ `vendor_dashboard/lib/services/vendor_service.dart` - Needs phone & gstNumber fields added to shop document

## Result:
**No more random data in invoice PDFs!** Shows real Firestore data or "N/A" if not available.
