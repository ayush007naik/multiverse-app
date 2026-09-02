import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:db_compat/db_compat.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/vendor_cyberpunk_theme.dart';
import 'screens/vendor_splash_screen.dart';
import 'screens/vendor_login_screen.dart';
import 'screens/vendor_signup_screen.dart';
import 'screens/vendor_forgot_password_screen.dart';
import 'screens/vendor_dashboard_main.dart';
import 'providers/order_provider.dart';
import 'services/fcm_service.dart';
import 'services/runtime_config_service.dart';
import 'services/vendor_service.dart';
import 'widgets/config_gate.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Enable Firebase Auth persistence for web
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
    } else {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
    
    debugPrint('✅ Firebase initialized successfully');

    // Supabase (PostgreSQL + Storage) — skipped when the anon key is missing.
    await SupabaseEnv.maybeInitialize();

    // Stream admin Dynamic Config (maintenance / force update).
    RuntimeConfigService.instance.init();

    // Initialize FCM for push notifications
    if (FirebaseAuth.instance.currentUser != null) {
      FCMService().initialize();
    }
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
  }
  
  runApp(const VendorDashboardApp());
}

class VendorDashboardApp extends StatelessWidget {
  const VendorDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OrderProvider(),
      child: MaterialApp(
        title: 'MULTIVERSE Vendor Dashboard',
        debugShowCheckedModeBanner: false,
        theme: VendorCyberpunkTheme.theme,
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const VendorLoginScreen(),
          '/vendor-signup': (context) => const VendorSignupScreen(),
          '/forgot-password': (context) => const VendorForgotPasswordScreen(),
          '/dashboard': (context) => const VendorDashboardMain(),
        },
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
            child: ConfigGate(child: child!),
          );
        },
      ),
    );
  }
}

/// Checks if user is logged in, is a vendor, and is approved before
/// showing the dashboard. Without this gate the dashboard would flash for a
/// moment on sign-in and then get kicked back to login when the login flow's
/// own validation signs the user out.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _vendorService = VendorService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show animated splash while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const VendorSplashScreen(autoNavigate: false);
        }

        // No user logged in → login
        final user = snapshot.data;
        if (user == null) {
          return const VendorLoginScreen();
        }

        // Validate vendor before showing the dashboard
        return FutureBuilder<bool>(
          future: _validateVendor(user.uid),
          builder: (context, gateSnapshot) {
            if (gateSnapshot.connectionState == ConnectionState.waiting) {
              return const _AuthGateLoadingScreen();
            }

            if (gateSnapshot.data == true) {
              debugPrint('✅ User is a valid vendor: ${user.uid}');
              WidgetsBinding.instance.addPostFrameCallback((_) => FCMService().initialize());
              return const VendorDashboardMain();
            }

            // Signed in but not an approved vendor → sign out and show login
            debugPrint('⚠️ User is not an approved vendor, signing out: ${user.uid}');
            if (FirebaseAuth.instance.currentUser?.uid == user.uid) {
              FirebaseAuth.instance.signOut();
            }
            return const VendorLoginScreen();
          },
        );
      },
    );
  }

  Future<bool> _validateVendor(String uid) async {
    try {
      if (!await _vendorService.isVendor(uid)) return false;
      return await _vendorService.isVendorApproved(uid);
    } catch (_) {
      return false;
    }
  }
}

class _AuthGateLoadingScreen extends StatelessWidget {
  const _AuthGateLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090D),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5F00).withValues(alpha: 0.6),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF5F00), Color(0xFF00F2FF)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 30),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5F00)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
