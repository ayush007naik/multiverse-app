#  Checkout System - Integration Quick Guide

## ⚡ 5-Minute Integration Steps

### Step 1: Connect CartScreen to PaymentScreen
**File**: `lib/screen/cart_screen.dart`

Add this button to your checkout button (replace or update existing):

```dart
ElevatedButton(
  onPressed: () {
    if (cartProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }
    
    // Convert cart items to payment screen format
    List<Map<String, dynamic>> items = cartProvider.items.values
        .map((item) => {
              'productId': item.id,
              'name': item.name,
              'price': item.price.toInt(),
              'qty': item.quantity,
              'image': item.image,
              'icon': item.image, // For display
            })
        .toList();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          total: cartProvider.totalAmount.toInt(),
          shopName: cartProvider.currentShopName,
          shopId: cartProvider.currentShopId,
          items: items,
        ),
      ),
    );
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFFF5722),
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
  child: const Text(
    'Proceed to Checkout',
    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
  ),
)
```

### Step 2: Add PaymentScreen Import
**File**: `lib/screen/cart_screen.dart`

Add at the top of the file:
```dart
import 'payment_screen.dart';
```

### Step 3: Verify Dependencies in pubspec.yaml

Ensure these are in your `pubspec.yaml`:
```yaml
dependencies:
  # Payment
  razorpay_flutter: ^1.4.4
  
  # Firebase
  firebase_core: ^2.32.0
  cloud_firestore: ^4.17.5
  firebase_auth: ^4.20.0
  
  # State Management
  provider: ^6.0.0
  
  # Local Storage
  shared_preferences: ^2.2.0
  
  # Location
  geolocator: ^10.1.0
```

Run:
```bash
flutter pub get
```

### Step 4: Verify Firebase Firestore Rules

Update your Firestore rules to allow order creation:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Orders: Authenticated users can create and read their own
    match /orders/{document=**} {
      allow create: if request.auth != null;
      allow read, update: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         resource.data.shopId == request.auth.uid);
    }
    
    // Products
    match /products/{document=**} {
      allow read: if request.auth != null;
    }
    
    // Users
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
  }
}
```

### Step 5: Test the Flow

1. **Add Items to Cart**
   - Navigate to a shop
   - Add products to cart
   - See badge update

2. **Go to Cart**
   - Click cart badge
   - Verify items display
   - Check total calculation

3. **Checkout Flow - COD**
   - Click "Proceed to Checkout"
   - Add new address or select existing
   - Select "Cash on Delivery"
   - Click "Place Order (COD)"
   - Verify success screen
   - Check Firestore for order

4. **Checkout Flow - Online Payment**
   - Click "Proceed to Checkout"
   - Add address
   - Select "UPI" or "Card"
   - Click "Pay ₹XXX"
   - Razorpay modal opens
   - Complete payment (test credentials)
   - Verify success screen
   - Check Firestore for order

---

##  Key Integration Points

### 1. CartProvider Methods
```dart
cartProvider.totalAmount      // Double - total price
cartProvider.totalItems       // Int - item count
cartProvider.currentShopId    // String - shop ID
cartProvider.currentShopName  // String - shop name
cartProvider.clear()          // Void - clear cart
```

### 2. PaymentScreen Constructor
```dart
PaymentScreen(
  total: int,                  // Total amount in rupees
  shopName: String,            // Shop name
  shopId: String,              // Shop ID
  items: List<Map>,            // Cart items
  deliveryAddress: String?,    // Optional address
  deliveryCity: String?,       // Optional city
  deliveryPincode: String?,    // Optional pincode
  customerName: String?,       // Optional customer name
  customerPhone: String?,      // Optional phone
)
```

### 3. Order Data Structure
```dart
{
  "userId": "user-id",
  "customerName": "Name",
  "customerPhone": "+91-XXXXXXXXXX",
  "shopId": "shop-id",
  "shopName": "Shop Name",
  "items": [
    {
      "productId": "id",
      "name": "Product",
      "price": 250,
      "qty": 2,
      "total": 500,
      "image": "url"
    }
  ],
  "totalAmount": 500,
  "paymentMethod": "COD|UPI|Card",
  "address": {
    "house": "123",
    "area": "Main St",
    "city": "Mandi",
    "pincode": "175001",
    "name": "Name",
    "phone": "+91-XXXXXXXXXX"
  },
  "status": "placed",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

---

## ✅ Integration Checklist

- [ ] PaymentScreen imported in CartScreen
- [ ] Button code added to CartScreen
- [ ] Dependencies in pubspec.yaml verified
- [ ] Firebase rules updated
- [ ] COD flow tested
- [ ] Online payment flow tested
- [ ] Order appears in Firestore
- [ ] Cart clears after order
- [ ] Success screen displays
- [ ] Error handling works

---

##  Common Issues & Fixes

### Issue: PaymentScreen not found
**Fix**: Add import statement
```dart
import 'payment_screen.dart';
```

### Issue: CartProvider not found
**Fix**: Ensure Provider is in pubspec.yaml
```dart
import 'package:provider/provider.dart';
```

### Issue: Firebase not saving order
**Fix**: 
1. Check Firestore rules
2. Verify user is authenticated
3. Check Firebase connection
4. See error in console

### Issue: Razorpay not opening
**Fix**:
1. Verify test key is correct
2. Check internet connection
3. Ensure amount > 0
4. Check device has payment apps

### Issue: Cart not clearing
**Fix**:
1. Ensure `cartProvider.clear()` is called
2. Check Provider is properly set up
3. Verify ChangeNotifier listeners

---

##  Support

For detailed information, refer to:
- `CHECKOUT_SYSTEM_COMPLETE.md` - Full documentation
- `payment_screen.dart` - Implementation details
- `add_address_screen.dart` - Address management
- `order_success_screen.dart` - Success flow

---

##  You're All Set!

The checkout system is fully integrated and ready to use.

**Test it now** → Add items → Proceed to checkout → Place order! ✅
