# Cart System Documentation

## Overview
A complete, production-ready shopping cart system for the Multiverses Flutter app with state management, persistence, and a clean UI.

## Features

### ✅ Core Features
- **Add Items to Cart** - Add products from any shop with automatic quantity increment
- **View Cart** - Beautiful cart screen showing all items with details
- **Remove Items** - Remove items individually or entire products
- **Modify Quantities** - Increase/decrease item quantities with simple controls
- **Cart State Management** - Uses Provider for state management across the app
- **Cart Persistence** - Cart data persists across app sessions using SharedPreferences
- **Single Shop Restriction** - Cart enforces single-shop rule (no mixing items from different shops)
- **Order Summary** - Detailed breakdown of subtotal, discount, delivery fee, and total
- **Coupon Support** - Apply discount codes (SAVE50 = ₹50 off)
- **Checkout Flow** - Dedicated checkout screen for address and payment details
- **Cart Badge** - Display cart count in app bars and navigation

## Architecture

### Models

#### `CartItem` (`lib/models/cart_model.dart`)
```dart
CartItem({
  String id,              // Product ID
  String name,            // Product name
  int quantity,           // Quantity in cart
  double price,           // Unit price
  String image,           // Product emoji/icon
  String shopId,          // Shop identifier
  String shopName,        // Shop name
})
```

### State Management

#### `CartProvider` (`lib/providers/cart_provider.dart`)
**Extends:** `ChangeNotifier`

**Properties:**
- `items` - Map of cart items
- `itemCount` - Number of unique items
- `totalItems` - Total quantity across all items
- `totalAmount` - Total price before fees/discounts
- `currentShopId` - Current shop in cart
- `currentShopName` - Current shop name

**Methods:**
```dart
// Add item to cart
addItem({
  required String productId,
  required String name,
  required double price,
  required String image,
  required String shopId,
  required String shopName,
  int quantity = 1,
})

// Remove entire product
removeItem(String productId)

// Decrease quantity by 1
removeSingleItem(String productId)

// Set exact quantity
setItemQuantity(String productId, int quantity)

// Clear entire cart
clear()
```

### Screens

#### 1. **CartScreen** (`lib/screen/cart_screen.dart`)
Main shopping cart display with:
- List of all cart items with images
- Quantity controls (±)
- Delete button for each item
- Coupon code input
- Order summary with pricing breakdown
- Proceed to checkout button

**Features:**
- Empty cart state with call-to-action
- Real-time total calculation
- Responsive design
- Smooth animations

#### 2. **CheckoutScreen** (`lib/screen/checkout_screen.dart`)
Complete checkout flow with:
- Order summary recap
- Delivery address form:
  - Full Name
  - Phone Number
  - Street Address
  - City
  - Pincode
- Items list review
- Security notice
- Proceed to payment button

**Features:**
- Form validation
- Auto-fill from Firebase Auth
- Clean, spacious UI
- Multiple form fields with icons

#### 3. **Shop Detail Screen** (Enhanced)
Already integrated with:
- Add to cart buttons
- Cart badge showing item count
- Handle different shop error

### Widgets

#### `CartBadgeIcon` (`lib/widgets/cart_badge_icon.dart`)
Badge icon for displaying cart count in app bars.

```dart
CartBadgeIcon(
  onTap: () => Navigator.push(...),
  badgeColor: Color(0xFFFF5722),
  iconColor: Colors.white,
)
```

#### `CartCountBadge`
Wrapper widget to add badge count to any widget.

```dart
CartCountBadge(
  child: Icon(Icons.shopping_cart),
  badgeColor: Color(0xFFFF5722),
)
```

### Utilities

#### `CartUtils` (`lib/utils/cart_utils.dart`)
Helper functions for common cart operations:

```dart
// Show snackbar when item added
CartUtils.showAddedToCartSnackbar(context, "Product Name")

// Handle different shop error
CartUtils.showDifferentShopError(context, currentShop, newShop)

// Add item with error handling
CartUtils.addItemToCart(
  context: context,
  productId: "p1",
  name: "Product",
  price: 250.0,
  image: "️",
  shopId: "s1",
  shopName: "Shop Name",
)

// Format prices
CartUtils.formatCurrency(250.0)  // "₹250"

// Get cart summary
CartUtils.getCartSummary(cart, discountAmount: 50, deliveryFee: 30)
```

## Usage Examples

### 1. Adding Items to Cart

**From Product Screen:**
```dart
final cart = Provider.of<CartProvider>(context, listen: false);

// Option 1: Direct add
cart.addItem(
  productId: product['id'],
  name: product['name'],
  price: product['price'],
  image: product['icon'],
  shopId: shop['id'],
  shopName: shop['name'],
);

// Option 2: With error handling using CartUtils
CartUtils.addItemToCart(
  context: context,
  productId: product['id'],
  name: product['name'],
  price: product['price'],
  image: product['icon'],
  shopId: shop['id'],
  shopName: shop['name'],
);
```

### 2. Displaying Cart Badge in AppBar

**From Home Screen:**
```dart
AppBar(
  actions: [
    CartBadgeIcon(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartScreen()),
        );
      },
    ),
  ],
)
```

### 3. Accessing Cart in Any Screen

```dart
final cart = Provider.of<CartProvider>(context);

// Get cart info
print('Items: ${cart.itemCount}');
print('Total items: ${cart.totalItems}');
print('Total price: ${cart.totalAmount}');

// Listen to changes
Consumer<CartProvider>(
  builder: (ctx, cart, _) {
    return Text('₹${cart.totalAmount}');
  },
)
```

### 4. Show Cart Screen from Anywhere

```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  },
  child: const Text('View Cart'),
)
```

## UI Design

### Color Scheme
- **Background:** `#0D0D0D` (Dark)
- **Surface:** `#1E1E1E` (Slightly lighter)
- **Border:** `#333333`
- **Primary Action:** `#FF5722` (Orange)
- **Text:** White & Gray tones

### Responsive Design
- Works on all device sizes
- Touch-friendly controls
- Proper padding and spacing
- Smooth scrolling

### Dark Theme
- AMOLED-friendly dark colors
- High contrast for readability
- Modern, clean aesthetic

## Data Persistence

### SharedPreferences Storage
Cart data is automatically saved to device storage:
- `cart_items` - JSON encoded cart items
- `shop_id` - Current shop ID
- `shop_name` - Current shop name

**Auto-loads on app startup** via `CartProvider` constructor.

## Error Handling

### Different Shop Error
When user tries to add items from a different shop:
```dart
// CartProvider automatically throws
throw Exception('items_from_different_shop');

// Handled by CartUtils with dialog
CartUtils.showDifferentShopError(context, currentShop, newShop);
```

### Form Validation
Checkout screen validates:
- Name (required)
- Phone (10 digits)
- Address (required)
- City (required)
- Pincode (6 digits)

## Integration Points

### With PaymentScreen
CheckoutScreen passes all necessary data:
```dart
PaymentScreen(
  total: finalTotal,
  shopName: firstItem.shopName,
  shopId: firstItem.shopId,
  items: cartItems,
  deliveryAddress: address,
  deliveryCity: city,
  deliveryPincode: pincode,
  customerName: name,
  customerPhone: phone,
)
```

### With Firebase Auth
Checkout auto-fills user data:
```dart
final user = FirebaseAuth.instance.currentUser;
_nameController.text = user.displayName ?? '';
_phoneController.text = user.phoneNumber ?? '';
```

## Best Practices

1. **Always use CartUtils** for adding items - handles errors gracefully
2. **Access cart with Consumer** when building UI that needs updates
3. **Use listen: false** when you only need the value, not reactive updates
4. **Clear cart after successful order** to prevent duplicate orders
5. **Show snackbars** for user feedback on cart actions

## Future Enhancements

- Wishlist/Save for later
- Cart sharing
- Bulk discounts
- Special offers based on cart value
- Cart history
- Payment method selection
- Loyalty points integration
- Cart recommendations based on items

## Dependencies

- `provider: ^6.1.1` - State management
- `shared_preferences: ^2.2.3` - Local persistence
- `firebase_auth: ^4.17.4` - User authentication
- `cloud_firestore: ^4.13.6` - Backend database

## File Structure

```
lib/
├── models/
│   └── cart_model.dart
├── providers/
│   └── cart_provider.dart
├── screen/
│   ├── cart_screen.dart
│   └── checkout_screen.dart
├── widgets/
│   └── cart_badge_icon.dart
├── utils/
│   └── cart_utils.dart
└── main.dart (includes CartProvider in MultiProvider)
```

## Troubleshooting

### Cart not persisting
- Ensure `shared_preferences` is installed
- Check app has file storage permissions
- Verify `_saveCartToStorage()` is called

### Different shop dialog not showing
- Verify `CartUtils.addItemToCart()` is used instead of direct `cart.addItem()`
- Check context is passed correctly

### Cart badge not updating
- Ensure using `Consumer<CartProvider>` not just `Provider.of`
- Verify `notifyListeners()` is called in CartProvider

### Checkout form not submitting
- Check all required fields are filled
- Verify phone is 10+ digits
- Verify pincode is 6+ digits
