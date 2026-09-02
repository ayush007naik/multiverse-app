import 'package:flutter/material.dart';

import 'home_screen.dart';

class EnhancedHomeScreen extends StatelessWidget {
  final bool showTracking;
  final Map<String, dynamic>? orderData;

  const EnhancedHomeScreen({
    super.key,
    this.showTracking = false,
    this.orderData,
  });

  @override
  Widget build(BuildContext context) {
    return HomeScreen(showTracking: showTracking, orderData: orderData);
  }
}
