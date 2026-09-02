import 'package:flutter/material.dart';
import 'basic_details_screen.dart';

class CustomerSignupScreen extends StatelessWidget {
  const CustomerSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BasicDetailsScreen(signupType: 'customer');
  }
}
