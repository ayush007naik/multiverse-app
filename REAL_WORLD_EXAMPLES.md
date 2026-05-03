# Cart Integration - Real-World Examples

This file contains practical, copy-paste ready examples for integrating the cart system into your existing screens.

## Example 1: HomeScreen - Add Cart Badge to AppBar

**Before:**
```dart
AppBar(
  backgroundColor: const Color(0xFF0D0D0D),
  title: const Text('Multiverses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
)
```

**After:**
```dart
import 'widgets/cart_badge_icon.dart';
import 'screen/cart_screen.dart';

AppBar(
  backgroundColor: const Color(0xFF0D0D0D),
  title: const Text('Multiverses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

---

## Example 2: ShopDetailScreen - Add to Cart Button

**Add this import:**
```dart
import 'package:utils/cart_utils.dart';
```

**Find your product card and update it:**
```dart
Widget _buildProductCard(
  BuildContext context,
  Map<String, dynamic> product,
  String shopName,
  String shopId,
) {
  return GestureDetector(
    onTap: () {
      // Optional: Show product detail
    },
    child: Container(
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
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(product['icon'], style: const TextStyle(fontSize: 40)),
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
                        shopId: shopId,
                        shopName: shopName,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Add to Cart', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

---

## Example 3: CategoryProductsScreen - Product Grid with Add Button

```dart
class CategoryProductsScreen extends StatelessWidget {
  final String category;
  final String shopName;
  final String shopId;

  const CategoryProductsScreen({
    required this.category,
    required this.shopName,
    required this.shopId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: Text(category, style: const TextStyle(color: Colors.white)),
        actions: [
          // Add cart badge here
          CartBadgeIcon(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: products.length,
        itemBuilder: (ctx, i) {
          final product = products[i];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return GestureDetector(
      onTap: () {
        // Show product detail if needed
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Text(product['icon'], style: const TextStyle(fontSize: 50)),
                ),
              ),
            ),
            
            // Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${product['price']}',
                      style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
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
                            shopId: shopId,
                            shopName: shopName,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5722),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        child: const Text('Add', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Example 4: Custom Add to Cart Dialog with Quantity

```dart
void _showAddToCartDialog(BuildContext context, Map<String, dynamic> product, String shopId, String shopName) {
  int quantity = 1;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(product['name'], style: const TextStyle(color: Colors.white)),
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Price
              Text(
                '₹${product['price']}',
                style: const TextStyle(color: Color(0xFFFF5722), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              // Quantity Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setState(() => quantity = max(1, quantity - 1)),
                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFFF5722)),
                  ),
                  SizedBox(
                    width: 50,
                    child: Center(
                      child: Text(
                        '$quantity',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => quantity++),
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF5722)),
                  ),
                ],
              ),
              
              // Total Price
              const SizedBox(height: 16),
              Text(
                'Total: ₹${product['price'] * quantity}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            CartUtils.addItemToCart(
              context: context,
              productId: product['id'],
              name: product['name'],
              price: product['price'].toDouble(),
              image: product['icon'],
              shopId: shopId,
              shopName: shopName,
              quantity: quantity,
            );
            Navigator.pop(ctx);
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5722)),
          child: const Text('Add to Cart'),
        ),
      ],
    ),
  );
}
```

---

## Example 5: Floating Action Button to Cart

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    // ... scaffold content ...
    floatingActionButton: Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.itemCount == 0) {
          return const SizedBox.shrink();
        }
        
        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
          backgroundColor: const Color(0xFFFF5722),
          label: Text('${cart.totalItems} Items'),
          icon: const Icon(Icons.shopping_cart),
        );
      },
    ),
  );
}
```

---

## Example 6: Bottom Navigation Badge

```dart
BottomNavigationBar(
  backgroundColor: const Color(0xFF0D0D0D),
  selectedItemColor: const Color(0xFFFF5722),
  unselectedItemColor: Colors.grey,
  currentIndex: _selectedTab,
  onTap: (index) => setState(() => _selectedTab = index),
  items: [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Home',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.category),
      label: 'Categories',
    ),
    BottomNavigationBarItem(
      icon: Consumer<CartProvider>(
        builder: (ctx, cart, _) {
          return Stack(
            children: [
              const Icon(Icons.shopping_cart),
              if (cart.itemCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      label: 'Cart',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ),
  ],
)
```

---

## Example 7: Cart Summary Widget

```dart
class CartSummaryWidget extends StatelessWidget {
  final double deliveryFee;
  final double discountAmount;

  const CartSummaryWidget({
    super.key,
    this.deliveryFee = 30,
    this.discountAmount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final total = cart.totalAmount - discountAmount + deliveryFee;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: Column(
            children: [
              _row('Subtotal (${cart.totalItems} items)', '₹${cart.totalAmount.toStringAsFixed(0)}'),
              if (discountAmount > 0) ...[
                const SizedBox(height: 8),
                _row('Discount', '-₹${discountAmount.toStringAsFixed(0)}', Colors.green),
              ],
              const SizedBox(height: 8),
              _row('Delivery', '₹${deliveryFee.toStringAsFixed(0)}'),
              const Divider(color: Color(0xFF333333), height: 20),
              _row(
                'Total',
                '₹${total.toStringAsFixed(0)}',
                const Color(0xFFFF5722),
                bold: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value, [Color color = Colors.white, bool bold = false]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
```

**Usage:**
```dart
CartSummaryWidget(
  deliveryFee: 30,
  discountAmount: 50,
)
```

---

## Example 8: Conditional Checkout Button

```dart
Consumer<CartProvider>(
  builder: (context, cart, _) {
    final isCartEmpty = cart.itemCount == 0;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isCartEmpty ? null : () => _proceedToCheckout(),
        style: ElevatedButton.styleFrom(
          backgroundColor: isCartEmpty ? Colors.grey : const Color(0xFFFF5722),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          isCartEmpty ? 'Add items to cart' : 'Proceed to Payment - ₹${cart.totalAmount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  },
)
```

---

## Example 9: Product Detail Screen with Add Button

```dart
class ProductDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  final String shopId;
  final String shopName;

  const ProductDetailScreen({
    required this.product,
    required this.shopId,
    required this.shopName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('Product', style: TextStyle(color: Colors.white)),
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
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              width: double.infinity,
              height: 300,
              color: const Color(0xFF1E1E1E),
              child: Center(
                child: Text(product['icon'], style: const TextStyle(fontSize: 100)),
              ),
            ),
            
            // Product Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  Text(
                    '₹${product['price']}',
                    style: const TextStyle(color: Color(0xFFFF5722), fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  // Rating
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      const Text('4.5 (128 reviews)', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Description
                  const Text(
                    'Product Details',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'High-quality product with excellent durability and design. Perfect for your needs.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  
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
                          shopId: shopId,
                          shopName: shopName,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5722),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add to Cart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Example 10: Show Cart in Bottom Sheet

```dart
void _showCartBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0D0D0D),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.itemCount == 0) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Cart is empty', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${cart.totalItems} items in cart',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                '₹${cart.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFFFF5722), fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('View Cart', style: TextStyle(fontWeight: FontWeight.bold)),
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

---

## Summary

These examples show how to integrate the cart system into:
- ✅ AppBars (with badge)
- ✅ Product cards/grids
- ✅ Add to cart dialogs
- ✅ Floating action buttons
- ✅ Bottom navigation
- ✅ Summary widgets
- ✅ Conditional buttons
- ✅ Bottom sheets
- ✅ Product detail pages

Copy and adapt these examples to your specific screens!
