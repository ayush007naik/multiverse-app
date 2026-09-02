import "package:flutter/material.dart";
import "package:animate_do/animate_do.dart";
import "package:provider/provider.dart";
import "../providers/auth_provider.dart";
import "welcome_screen.dart";
import "verification_pending_screen.dart";
import "dashboard/dashboard_screen.dart";

class CustomSplashScreen extends StatefulWidget {
  const CustomSplashScreen({super.key});

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    // Wait until auth status is resolved (not the initial unauthenticated or authenticating)
    if (authProvider.status == AuthStatus.unauthenticated || authProvider.status == AuthStatus.authenticating) {
      try {
        await authProvider.checkUserStatus();
      } catch (_) {}
    }

    if (!mounted) return;

    if (authProvider.status == AuthStatus.authenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdaptiveDashboardShell()),
      );
    } else if (authProvider.status == AuthStatus.pendingApproval) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const VerificationPendingScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const WelcomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeInDown(
              duration: const Duration(seconds: 2),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6A00).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFF6A00).withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Image.asset("assets/appointment.png"),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeInUp(
              duration: const Duration(seconds: 2),
              child: Column(
                children: [
                  Text(
                    "APPOINTMENTS",
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "by MULTIVERSE CITY",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      letterSpacing: 4,
                      color: const Color(0xFFFF6A00),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            FadeIn(
              delay: const Duration(seconds: 1),
              child: const SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeIn(
              delay: const Duration(seconds: 2),
              child: Text(
                "Initializing Secure Connection...",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
