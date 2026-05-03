# Firestore Product System - Security Rules & Index Setup

## 🔥 CRITICAL: Fix Firestore Product Loading Errors

This guide will help you fix all Firestore product loading errors by setting up proper security rules and indexes.

---

## 1️⃣ FIRESTORE SECURITY RULES

### Problem:
If you're getting "Permission Denied" errors, your Firestore security rules are blocking read/write access to products.

### Solution:

**Step 1:** Go to Firebase Console → Firestore Database → Rules tab

**Step 2:** Replace your current rules with these:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user is admin
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Helper function to check if user is vendor
    function isVendor() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'vendor';
    }
    
    // ===== SHOPS COLLECTION =====
    match /shops/{shopId} {
      // Anyone can read active shops
      allow read: if true;
      
      // Only authenticated users can create shops
      allow create: if isAuthenticated();
      
      // Only shop owner or admin can update
      allow update: if isAuthenticated() && 
                       (request.auth.uid == resource.data.ownerId || isAdmin());
      
      // Only admin can delete shops
      allow delete: if isAdmin();
      
      // ===== PRODUCTS SUBCOLLECTION =====
      match /products/{productId} {
        // Anyone can read available products
        allow read: if true;
        
        // Shop owner or admin can create products
        allow create: if isAuthenticated() && 
                         (request.auth.uid == get(/databases/$(database)/documents/shops/$(shopId)).data.ownerId || 
                          isAdmin());
        
        // Shop owner or admin can update products
        allow update: if isAuthenticated() && 
                         (request.auth.uid == get(/databases/$(database)/documents/shops/$(shopId)).data.ownerId || 
                          isAdmin());
        
        // Shop owner or admin can delete products
        allow delete: if isAuthenticated() && 
                         (request.auth.uid == get(/databases/$(database)/documents/shops/$(shopId)).data.ownerId || 
                          isAdmin());
      }
    }
    
    // ===== USERS COLLECTION =====
    match /users/{userId} {
      // Users can read their own profile
      allow read: if isAuthenticated() && request.auth.uid == userId;
      
      // Users can create their own profile
      allow create: if isAuthenticated() && request.auth.uid == userId;
      
      // Users can update their own profile
      allow update: if isAuthenticated() && request.auth.uid == userId;
      
      // Only admin can delete users
      allow delete: if isAdmin();
    }
    
    // ===== ORDERS COLLECTION =====
    match /orders/{orderId} {
      // Users can read their own orders
      // Vendors can read orders for their shops
      // Admins can read all orders
      allow read: if isAuthenticated() && 
                     (request.auth.uid == resource.data.customerId || 
                      request.auth.uid == resource.data.vendorId || 
                      isAdmin());
      
      // Customers can create orders
      allow create: if isAuthenticated() && 
                       request.auth.uid == request.resource.data.customerId;
      
      // Vendor or admin can update order status
      allow update: if isAuthenticated() && 
                       (request.auth.uid == resource.data.vendorId || isAdmin());
      
      // Only admin can delete orders
      allow delete: if isAdmin();
    }
    
    // ===== COLLECTION GROUP QUERIES =====
    // Allow collectionGroup queries on products
    // This is handled by the individual collection rules above
  }
}
```

### Simplified Rules (For Testing Only):
⚠️ **WARNING:** Use this ONLY for debugging. NOT for production!

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow all read/write operations (TESTING ONLY!)
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

---

## 2️⃣ FIRESTORE INDEXES

### Problem:
If you're getting "The query requires an index" error, you need to create composite indexes.

### Required Indexes:

#### Index 1: Shop Products (isAvailable + createdAt)
**Collection:** `products` (subcollection of `shops`)
**Fields:**
- `isAvailable` - Ascending
- `createdAt` - Descending

**Create via Console:**
1. Go to Firebase Console → Firestore → Indexes tab
2. Click "Create Index"
3. Collection ID: `products`
4. Fields to index:
   - `isAvailable` - Ascending
   - `createdAt` - Descending
5. Query scope: Collection

**Create via CLI:**
```bash
firebase index:create
```

Add to `firestore.indexes.json`:
```json
{
  "indexes": [
    {
      "collectionGroup": "products",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "isAvailable",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    }
  ]
}
```

#### Index 2: Vendor Products (vendorId + createdAt)
**Collection Group:** `products`
**Fields:**
- `vendorId` - Ascending
- `createdAt` - Descending

**Create via Console:**
1. Go to Firebase Console → Firestore → Indexes tab
2. Click "Create Index"
3. Collection ID: `products`
4. Fields to index:
   - `vendorId` - Ascending
   - `createdAt` - Descending
5. Query scope: Collection Group

**Add to `firestore.indexes.json`:**
```json
{
  "indexes": [
    {
      "collectionGroup": "products",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        {
          "fieldPath": "vendorId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    }
  ]
}
```

### Complete `firestore.indexes.json`:
```json
{
  "indexes": [
    {
      "collectionGroup": "products",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "isAvailable",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    },
    {
      "collectionGroup": "products",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        {
          "fieldPath": "vendorId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "createdAt",
          "order": "DESCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}
```

### Deploy Indexes:
```bash
firebase deploy --only firestore:indexes
```

---

## 3️⃣ DEBUGGING STEPS

### Step 1: Check Console Logs
Run your app and look for these logs in the console:

```
🏪 [ShopDetail] Loading products for shopId: abc123
🏪 [ShopDetail] Shop data: {id: abc123, name: My Shop, ...}
⏳ [ShopDetail] Products loading...
✅ [ShopDetail] Loaded 5 products
```

**OR if there's an error:**
```
❌ [ShopDetail] ERROR loading products:
   Error: [FIRESTORE] Permission denied
   Stack Trace: #0      MethodChannelQuery.get...
   ConnectionState: ConnectionState.done
   Shop ID: abc123
```

### Step 2: Validate shopId
Check these logs:
```
🔥 [ProductService] Streaming products for shop: abc123
🔥 [ProductService] Query path: shops/abc123/products
```

**If shopId is empty:**
```
⚠️ [ShopDetail] shopId is EMPTY! Shop: {name: My Shop}
🔥 [ProductService] ERROR: shopId is empty!
```

### Step 3: Check Error Details
The error message will tell you exactly what's wrong:

| Error Message | Problem | Solution |
|--------------|---------|----------|
| `Permission denied` | Security rules blocking access | Update Firestore security rules (see section 1) |
| `The query requires an index` | Missing composite index | Create required indexes (see section 2) |
| `shopId cannot be empty` | shopId is null/empty | Check shop data being passed to screen |
| `vendorId cannot be empty` | vendorId is null/empty | Check user authentication |
| `Network error` | No internet connection | Check network connectivity |

### Step 4: Test Collection Path
Verify your Firestore structure matches:

```
firestore
  └── shops
       └── {shopId}
            ├── name: "My Shop"
            ├── ownerId: "user123"
            └── products (subcollection)
                 └── {productId}
                      ├── shopId: "abc123"
                      ├── vendorId: "user123"
                      ├── name: "Product 1"
                      ├── price: 100
                      ├── isAvailable: true
                      ├── isActive: true
                      └── createdAt: Timestamp
```

### Step 5: Temporary Filter Removal
If the `where` filter is causing issues, the code will automatically fallback to querying without it:

```dart
// In ProductService.streamShopProducts():
try {
  // Try with filter first
  return _firestore
      .collection('shops')
      .doc(shopId)
      .collection('products')
      .where('isAvailable', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .snapshots();
} catch (e) {
  // Fallback: return all products without filter
  return _firestore
      .collection('shops')
      .doc(shopId)
      .collection('products')
      .orderBy('createdAt', descending: true)
      .snapshots();
}
```

---

## 4️⃣ COMMON ISSUES & SOLUTIONS

### Issue 1: "Permission Denied" Error
**Symptoms:**
```
Error: [FIRESTORE] Permission denied
```

**Solution:**
1. Check security rules (see section 1)
2. Verify user is authenticated (if required)
3. For testing, use open rules temporarily:
   ```javascript
   match /{document=**} {
     allow read, write: if true;
   }
   ```

### Issue 2: "Missing Index" Error
**Symptoms:**
```
Error: The query requires an index. You can create it here: https://console.firebase.google.com/...
```

**Solution:**
1. Click the link in the error message (easiest way)
2. OR create indexes manually (see section 2)
3. OR deploy indexes via CLI:
   ```bash
   firebase deploy --only firestore:indexes
   ```

### Issue 3: shopId is Null or Empty
**Symptoms:**
```
⚠️ [ShopDetail] shopId is EMPTY!
```

**Solution:**
1. Check how shop data is being passed:
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (_) => ShopDetailScreen(shop: shopData),
     ),
   );
   ```

2. Verify shop data has 'id' field:
   ```dart
   print('Shop data: $shopData');
   // Should output: {id: abc123, name: My Shop, ...}
   ```

3. Fix shop service to include ID:
   ```dart
   final shops = snapshot.docs.map((doc) {
     return {
       'id': doc.id, // ✅ Don't forget this!
       ...doc.data(),
     };
   }).toList();
   ```

### Issue 4: Products Not Showing
**Symptoms:**
- No products visible
- Console shows: `Loaded 0 products`

**Solution:**
1. Check Firestore has products in correct path:
   ```
   shops/{shopId}/products/{productId}
   ```

2. Verify product has required fields:
   - `shopId` (string)
   - `vendorId` (string)
   - `name` (string)
   - `price` (number)
   - `isAvailable` (boolean)
   - `createdAt` (timestamp)

3. Check `isAvailable` is true:
   ```dart
   // Query filters: .where('isAvailable', isEqualTo: true)
   // If product has isAvailable: false, it won't show!
   ```

### Issue 5: collectionGroup Query Failing
**Symptoms:**
```
❌ [AdminScreen] ERROR loading products (collectionGroup):
```

**Solution:**
1. Ensure security rules allow collectionGroup queries
2. Check indexes are created for collectionGroup
3. Try without orderBy (code already has fallback):
   ```dart
   // Fallback query without orderBy
   return _firestore
       .collectionGroup('products')
       .where('vendorId', isEqualTo: vendorId)
       .snapshots();
   ```

---

## 5️⃣ TESTING CHECKLIST

### ✅ Before Deploying to Production:

- [ ] Security rules are properly configured (not open rules)
- [ ] All required indexes are created
- [ ] Console logs show successful product loading
- [ ] ShopDetailScreen shows products correctly
- [ ] VendorDashboard shows products correctly
- [ ] AdminScreen shows products correctly
- [ ] Error handling displays user-friendly messages
- [ ] Retry button works when errors occur
- [ ] Empty shopId is handled gracefully
- [ ] Products with `isAvailable: false` are filtered for customers

### ✅ Firestore Structure Validation:

```javascript
// ✅ Correct structure
shops/
  ├── abc123/
  │   ├── name: "My Shop"
  │   ├── ownerId: "user123"
  │   └── products/
  │        ├── prod1/
  │        │   ├── shopId: "abc123"
  │        │   ├── vendorId: "user123"
  │        │   ├── isAvailable: true
  │        │   └── createdAt: Timestamp
  │        └── prod2/
  │            ├── shopId: "abc123"
  │            ├── vendorId: "user123"
  │            ├── isAvailable: true
  │            └── createdAt: Timestamp
  └── def456/
      └── products/
           └── prod3/
               ├── shopId: "def456"
               ├── vendorId: "user456"
               ├── isAvailable: true
               └── createdAt: Timestamp
```

---

## 6️⃣ DEBUG MODE

### Enable/Disable Debug Logging:

In `ProductService`:
```dart
class ProductService {
  // Set to false to disable all debug logs
  static bool debugMode = true;
  
  // ... rest of the code
}
```

### Console Log Format:
```
🔥 [ProductService] Streaming products for shop: abc123
🔥 [ProductService] Query path: shops/abc123/products
🏪 [ShopDetail] Loading products for shopId: abc123
⏳ [ShopDetail] Products loading...
✅ [ShopDetail] Loaded 5 products
```

### Error Log Format:
```
❌ [ShopDetail] ERROR loading products:
   Error: [FIRESTORE] Permission denied
   Stack Trace: #0      MethodChannelQuery.get...
   ConnectionState: ConnectionState.done
   Shop ID: abc123
```

---

## 7️⃣ QUICK FIX COMMANDS

### Deploy Security Rules:
```bash
firebase deploy --only firestore:rules
```

### Deploy Indexes:
```bash
firebase deploy --only firestore:indexes
```

### Deploy Both:
```bash
firebase deploy --only firestore
```

### Check Firestore Emulator (if using):
```bash
firebase emulators:start --only firestore
```

---

## 🎯 SUMMARY

1. ✅ **Error Logging:** All errors are now logged with full details
2. ✅ **shopId Validation:** Empty shopId is caught early
3. ✅ **Filter Fallback:** Failing where filters are removed automatically
4. ✅ **Error UI:** User-friendly error display with retry button
5. ✅ **Security Rules:** Copy-paste rules provided
6. ✅ **Indexes:** Required indexes documented
7. ✅ **Debug Mode:** Toggle logging on/off

### Next Steps:
1. Copy security rules to Firebase Console
2. Create required indexes (or click link in error)
3. Run app and check console logs
4. Verify products load successfully
5. Test error handling and retry functionality

---

**Need Help?**
Check the console logs - they will tell you exactly what's wrong! 🎯
