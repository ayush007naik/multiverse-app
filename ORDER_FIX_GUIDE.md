# 🔴 Order Failed - Quick Diagnostic

## Common Causes & Fixes:

### 1️⃣ **Vendor Shop is Closed** (Most Likely)
**Fix:** 
- Open Firebase Console → Firestore
- Go to `vendors` collection
- Find your vendor document
- Add/edit field: `isShopOpen` → set to **`true`** (boolean)
- Add/edit field: `status` → set to **`"approved"`** (string)

### 2️⃣ **Missing Vendor ID in Cart**
**Fix:**
- The cart items MUST have `vendorId` field
- Check if products were added with vendor info
- Try adding products again from shop detail page

### 3️⃣ **Missing Address**
**Fix:**
- Make sure you've selected a delivery address on checkout screen
- Address must have: `name`, `phone`, `address`, `lat`, `lng`

### 4️⃣ **Firestore Permissions**
**Fix:**
- Check Firestore security rules
- Make sure authenticated users can create orders:
```
match /orders/{orderId} {
  allow create: if request.auth != null;
  allow read, update: if request.auth != null;
}
```

### 5️⃣ **Empty Cart**
**Fix:**
- Make sure cart has items before checkout
- Try adding items again

---

## 🔍 How to See Exact Error:

Since you're on phone, do this:

1. **Connect phone via USB** to computer
2. **Run:** `flutter logs` in terminal
3. **Place order** on phone
4. **Check terminal** for error message starting with ❌

OR

**Check Firebase Console:**
1. Go to Firestore
2. Check if ANY order was created (even partially)
3. If no order exists → write permission issue
4. If order exists → issue is after creation

---

## ⚡ Quick Test:

**Bypass shop check temporarily:**
1. Open `lib/screen/checkout_screen_v2.dart`
2. Find line ~2848: `final shopOpenCheck = await _checkShopStatusBeforeOrder();`
3. Comment it out: `// final shopOpenCheck...`
4. Try order again
5. If it works → shop status was the issue!

---

## 📱 What to Check RIGHT NOW:

Go to Firebase Console and verify:
- ✅ `vendors/{vendorId}/isShopOpen` = `true`
- ✅ `vendors/{vendorId}/status` = `"approved"`
- ✅ `shops/{shopId}` exists
- ✅ User is logged in (check Auth)

**Most likely your vendor's `isShopOpen` is false or missing!**
