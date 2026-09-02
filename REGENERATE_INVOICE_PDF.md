# 🔄 How to Fix Invoice PDF Showing Old Data

## Problem:
Invoice PDF still showing old random data (22AAAAA0000A1Z5, Mandi HP, etc.) even after code fixes.

## Root Cause:
**PDFs are generated once and cached in Firebase Storage.** Old invoices were generated with the old code that used random fallback data.

## Solution: Delete Old Invoice & Regenerate

### Method 1: Manual Delete from Firebase Console (Recommended)

1. **Open Firebase Console**
   - Go to https://console.firebase.google.com
   - Select your project

2. **Navigate to Firestore**
   - Click **"Firestore Database"** → **"Data"**

3. **Find Invoices Collection**
   - Click on **`invoices`** collection
   - Find the invoice document (e.g., `INV_abc12345`)

4. **Delete the Invoice**
   - Click on the invoice document
   - Click **"Delete document"** button at top
   - Confirm deletion

5. **Regenerate in App**
   - Open your app
   - Go to the order
   - Click "View Invoice" or "Download Invoice"
   - **New PDF will generate** with fixed code showing:
     - Real GST number OR `000000000`
     - Real phone OR `000000000`
     - Real location from Firestore

---

### Method 2: Delete ALL Old Invoices (Clean Slate)

If you want to delete all old invoices at once:

1. **Firebase Console** → **Firestore Database**
2. Click on **`invoices`** collection
3. Select all documents (checkbox)
4. Click **"Delete"**
5. All old invoices deleted
6. Next time anyone views an invoice, it regenerates with new code

---

### Method 3: Run This Flutter Code (Programmatic)

Add this temporary function to delete old invoice:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Call this once to delete old invoice
Future<void> deleteOldInvoice(String orderId) async {
  final invoiceId = 'INV_$orderId';
  
  await FirebaseFirestore.instance
      .collection('invoices')
      .doc(invoiceId)
      .delete();
  
  print('✅ Old invoice deleted: $invoiceId');
  print('🔄 Next time you view invoice, it will regenerate with new code');
}

// Usage:
// deleteOldInvoice('your_order_id_here');
```

---

## What Happens After Delete:

1. **Old PDF deleted** from Firestore
2. **Open invoice screen** → Checks if invoice exists
3. **Invoice doesn't exist** → Triggers regeneration
4. **New PDF generated** using fixed code:
   - ✅ Reads real `gstNumber` from shop/vendor
   - ✅ Reads real `phone` from shop/vendor  
   - ✅ Reads real `locationLabel` from shop
   - ✅ Shows `000000000` if data not available
   - ❌ NO MORE random fallback data!

---

## Verification:

After regenerating, check the new PDF shows:

**FROM Section:**
```
Shop Name: [Real name from Firestore] ✅
Phone: [Real phone or 000000000] ✅
Address: [Real location or N/A] ✅
GSTIN: [Real GST or 000000000] ✅
```

**NOT:**
```
❌ 22AAAAA0000A1Z5 (random)
❌ +91 7018741456 (random)
❌ Mandi, Himachal Pradesh (random)
```

---

## Quick Steps Summary:

1. ✅ Delete old invoice from Firebase Console → invoices collection
2. ✅ Open app → View invoice
3. ✅ New PDF generates with real data
4. ✅ Done!

**That's it!** The code is already fixed. Just need to delete old cached PDFs so they regenerate. 🎉
