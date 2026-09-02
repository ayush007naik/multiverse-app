import 'package:flutter/material.dart';
import 'basic_details_screen.dart';

class ProviderSignupScreen extends StatelessWidget {
  const ProviderSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BasicDetailsScreen(signupType: 'provider');
  }
}
