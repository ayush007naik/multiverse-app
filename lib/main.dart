import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screen/splash_screen.dart';
import 'providers/cart_provider.dart';
import 'providers/location_provider.dart';
import 'providers/order_provider.dart';
import 'providers/product_provider.dart';
import 'providers/theme_provider.dart';
import 'screen/invoice_list_screen.dart';
import 'screen/monthly_report_screen.dart';
import 'services/branding_service.dart';
import 'services/notification_service.dart';
import 'services/movie_service.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  // Ensure widgets are initialized
  
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ [Main] Widgets initialized');

  // Initialize Firebase and services (non-blocking)
  try {
    debugPrint(' [Main] Initializing Firebase...');
    await Firebase.initializeApp();
    debugPrint('✅ [Main] Firebase initialized');

    // Initialize services asynchronously
    debugPrint(' [Main] Initializing services...');
    BrandingService().initializeDefaultMetadata().catchError((e) {
      debugPrint('⚠️ [Main] Branding init failed: $e');
    });

    NotificationService().initialize().catchError((e) {
      debugPrint('⚠️ [Main] Notification init failed: $e');
    });

    // Initialize movie service and add sample movie
    MovieService().addMovie(
      title: 'Pushpa 2',
      genre: 'Action, Drama',
      duration: 180,
      rating: 8.5,
      language: 'Hindi',
      posterUrl: 'https://example.com/pushpa2-poster.jpg',
      description: 'The epic conclusion of the Pushpa saga continues with more action, drama, and intensity.',
      status: 'now_showing',
    ).catchError((e) {
      debugPrint('⚠️ [Main] Movie init failed: $e');
    });

    debugPrint('✅ [Main] Services initialized');
  } catch (e) {
    debugPrint('⚠️ [Main] Firebase init failed: $e');
    // Continue anyway - app will work with limited functionality
  }

  // Run app
  debugPrint(' [Main] Starting app');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
      ],
      child: const MultiverseApp(),
    ),
  );
}

class MultiverseApp extends StatelessWidget {
  const MultiverseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'Multiverse',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeProvider.lightTheme,
      darkTheme: ThemeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
      routes: {
        '/invoices': (context) => const InvoiceListScreen(),
        '/monthly-report': (context) => const MonthlyReportScreen(),
      },
    );
  }
}