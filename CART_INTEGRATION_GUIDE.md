# Cart System - Integration Guide

This guide shows how to integrate the cart system into your existing screens.

## Quick Start

### 1. Install Dependencies
```bash
flutter pub get
```

Dependencies added:
- `shared_preferences: ^2.2.3` (for cart persistence)

### 2. Access Cart Anywhere

```dart
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';

// Get cart reference
final cart = Provider.of<CartProvider>(context, listen: false);

// Or use Consumer for reactive updates
Consumer<CartProvider>(
  builder: (context, cart, _) {
    return Text('Total: ₹${cart.totalAmount}');
  },
)
```

## Integration Examples

### Example 1: Add Button in Product List

**Location:** Any product screen (HomeScreen, ShopDetailScreen, etc.)

```dart
import 'utils/cart_utils.dart';

ElevatedButton(
  onPressed: () {
    CartUtils.addItemToCart(
      context: context,
      productId: product['id'],
      name: product['name'],
      price: product['price'].toDouble(),
      image: product['icon'],
      shopId: shop['id'],
      shopName: shop['name'],
    );
  },
  child: const Text('Add to Cart'),
)
```

### Example 2: Cart Icon in AppBar

**Location:** HomeScreen, ShopDetailScreen AppBar

```dart
import 'widgets/cart_badge_icon.dart';
import 'screen/cart_screen.dart';

AppBar(
  title: const Text('Home'),
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

### Example 3: Display Cart Count

**Location:** Any screen to show cart summary

```dart
Consumer<CartProvider>(
  builder: (context, cart, _) {
    if (cart.itemCount == 0) {
      return const Text('Cart Empty');
    }
    return Column(
      children: [
        Text('Items: ${cart.totalItems}'),
        Text('Total: ₹${cart.totalAmount.toStringAsFixed(0)}'),
      ],
    );
  },
)
```

### Example 4: Floating Action Button to Cart

**Location:** Any product browsing screen

```dart
floatingActionButton: Consumer<CartProvider>(
  builder: (context, cart, _) {
    if (cart.itemCount == 0) return const SizedBox.shrink();
    
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartScreen()),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.shopping_cart),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${cart.totalItems}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  },
),
```

### Example 5: Quantity Selector Dialog

**Location:** Product detail screen

```dart
showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    backgroundColor: const Color(0xFF1E1E1E),
    title: const Text('Select Quantity', style: TextStyle(color: Colors.white)),
    content: StatefulBuilder(
      builder: (context, setState) {
        int qty = 1;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() => qty = max(1, qty - 1)),
                  icon: const Icon(Icons.remove, color: Colors.white),
                ),
                Text('$qty', style: const TextStyle(color: Colors.white, fontSize: 18)),
                IconButton(
                  onPressed: () => setState(() => qty++),
                  icon: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {
                final cart = Provider.of<CartProvider>(ctx, listen: false);
                cart.addItem(
                  productId: product['id'],
                  name: product['name'],
                  price: product['price'],
                  image: product['icon'],
                  shopId: shop['id'],
                  shopName: shop['name'],
                  quantity: qty,
                );
                Navigator.pop(ctx);
                CartUtils.showAddedToCartSnackbar(ctx, product['name']);
              },
              child: const Text('Add to Cart'),
            ),
          ],
        );
      },
    ),
  ),
);
```

### Example 6: Swipe to Delete from Cart

**Location:** Custom CartScreen enhancement

```dart
Dismissible(
  key: Key(cartItem.id),
  direction: DismissDirection.endToStart,
  onDismissed: (direction) {
    cart.removeItem(cartItem.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${cartItem.name} removed')),
    );
  },
  background: Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    color: Colors.red.withOpacity(0.8),
    child: const Icon(Icons.delete, color: Colors.white),
  ),
  child: CartItemWidget(item: cartItem),
)
```

### Example 7: Auto-clear Cart After Order

**Location:** OrderSuccessScreen

```dart
@override
void initState() {
  super.initState();
  // Clear cart after successful order
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Provider.of<CartProvider>(context, listen: false).clear();
  });
}
```

### Example 8: Cart Summary Widget

**Location:** Reusable widget for showing cart totals

```dart
import 'utils/cart_utils.dart';

class CartSummaryWidget extends StatelessWidget {
  final double discount;
  final double deliveryFee;

  const CartSummaryWidget({
    super.key,
    this.discount = 0,
    this.deliveryFee = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final summary = CartUtils.getCartSummary(
          cart,
          discountAmount: discount,
          deliveryFee: deliveryFee,
        );

        return Column(
          children: [
            _row('Subtotal', '₹${summary['subtotal']}'),
            if (summary['discount'] > 0)
              _row('Discount', '-₹${summary['discount']}', Colors.green),
            _row('Delivery', '₹${summary['deliveryFee']}'),
            const Divider(color: Color(0xFF333333)),
            _row('Total', '₹${summary['total']}', Colors.orange, bold: true),
          ],
        );
      },
    );
  }

  Widget _row(String label, String value, [Color color = Colors.white, bool bold = false]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey)),
        Text(value, style: TextStyle(
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        )),
      ],
    );
  }
}
```

### Example 9: Conditional Button State

**Location:** Checkout screen

```dart
Consumer<CartProvider>(
  builder: (context, cart, _) {
    return ElevatedButton(
      onPressed: cart.itemCount == 0 ? null : () => _checkout(),
      style: ElevatedButton.styleFrom(
        backgroundColor: cart.itemCount == 0 ? Colors.grey : const Color(0xFFFF5722),
      ),
      child: Text(
        cart.itemCount == 0 ? 'Add items to cart' : 'Proceed to Payment',
      ),
    );
  },
)
```

### Example 10: Restore Cart on App Launch

**Location:** SplashScreen or after login

```dart
@override
void initState() {
  super.initState();
  _initializeApp();
}

Future<void> _initializeApp() async {
  // CartProvider automatically loads from storage in constructor
  // But you can also manually trigger:
  if (mounted) {
    Provider.of<CartProvider>(context, listen: false);
  }
  
  // Continue with other initialization
  await _checkAuth();
}
```

## Common Patterns

### Pattern 1: Product Card with Add Button

```dart
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic> shop;

  const ProductCard({required this.product, required this.shop});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image/Icon
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                product['icon'],
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Product Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${product['price']}',
                  style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                // Add to Cart Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      CartUtils.addItemToCart(
                        context: context,
                        productId: product['id'],
                        name: product['name'],
                        price: product['price'].toDouble(),
                        image: product['icon'],
                        shopId: shop['id'],
                        shopName: shop['name'],
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                    ),
                    child: const Text('Add', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

### Pattern 2: Bottom Sheet Cart Preview

```dart
void _showCartPreview() {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0D0D0D),
    builder: (ctx) => Consumer<CartProvider>(
      builder: (context, cart, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${cart.totalItems} items in cart',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '₹${cart.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFFFF5722),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5722),
                  ),
                  child: const Text('View Cart'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
```

## Testing the Cart System

### Manual Testing Checklist

- [ ] Add item to empty cart
- [ ] Add same item again (should increment qty)
- [ ] Add item from different shop (should show error)
- [ ] Clear cart and add from different shop (should work)
- [ ] Remove item (check cart updates)
- [ ] Decrease quantity to 0 (item should remove)
- [ ] Apply valid coupon (SAVE50)
- [ ] Apply invalid coupon
- [ ] Fill checkout form with invalid data (should show errors)
- [ ] Fill checkout form correctly and proceed
- [ ] Close app and reopen (cart should persist)
- [ ] Cart badge should update as items added/removed

## Performance Tips

1. **Use `listen: false`** when you only need the value:
   ```dart
   final cart = Provider.of<CartProvider>(context, listen: false);
   ```

2. **Use `Consumer`** only when you need reactive updates:
   ```dart
   Consumer<CartProvider>(
     builder: (ctx, cart, _) => Text('${cart.totalItems}'),
   )
   ```

3. **Avoid rebuilds** by moving Consumer widgets down the tree:
   ```dart
   // ❌ Bad - rebuilds entire subtree
   Consumer<CartProvider>(
     builder: (ctx, cart, _) => Column(
       children: [
         ExpensiveWidget(),
         Text('${cart.totalItems}'),
       ],
     ),
   )

   // ✅ Good - only rebuilds the text
   Column(
     children: [
       ExpensiveWidget(),
       Consumer<CartProvider>(
         builder: (ctx, cart, _) => Text('${cart.totalItems}'),
       ),
     ],
   )
   ```

## Troubleshooting

### Issue: Cart not updating UI
- **Solution:** Use `Consumer<CartProvider>` instead of `Provider.of`

### Issue: Different shop error not showing
- **Solution:** Use `CartUtils.addItemToCart()` instead of direct `cart.addItem()`

### Issue: Cart not persisting between sessions
- **Solution:** Ensure `shared_preferences` is added to pubspec.yaml and `pub get` is run

### Issue: Checkout form not validating
- **Solution:** Check all required fields have proper validators and form is inside a `Form` widget

## Next Steps

1. Integrate cart icon into all product screens
2. Add wishlist functionality
3. Implement order history
4. Add loyalty points
5. Create cart recommendations feature
