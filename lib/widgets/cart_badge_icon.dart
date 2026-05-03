import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

class CartBadgeIcon extends StatelessWidget {
  final VoidCallback onTap;
  final Color? badgeColor;
  final Color? iconColor;

  const CartBadgeIcon({
    super.key,
    required this.onTap,
    this.badgeColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.shopping_cart,
                  color: iconColor ?? Colors.white,
                  size: 24,
                ),
              ),
              if (cart.totalItems > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: badgeColor ?? const Color(0xFFFF4D4F),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFF0D0D0D), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '${cart.totalItems}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CartCountBadge extends StatelessWidget {
  final Widget child;
  final Color? badgeColor;

  const CartCountBadge({
    super.key,
    required this.child,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.totalItems == 0) {
          return child;
        }
        return Stack(
          children: [
            child,
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: badgeColor ?? const Color(0xFFFF4D4F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0D0D0D), width: 2),
                ),
                child: Center(
                  child: Text(
                    '${cart.totalItems > 99 ? '99+' : cart.totalItems}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
