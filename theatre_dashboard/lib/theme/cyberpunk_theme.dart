import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CyberpunkTheme {
  static const Color black = Color(0xFF08080E);
  static const Color darkBg = Color(0xFF0D0518);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color primaryNeon = Color(0xFFFF5F00); // Orange Neon
  static const Color secondaryNeon = Color(0xFF9D00FF); // Purple Neon
  static const Color accentNeon = Color(0xFF00F2FF); // Cyan Neon
  static const Color glassColor = Color(0x1AFFFFFF);
  
  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryNeon,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryNeon,
        secondary: secondaryNeon,
        surface: surface,
        onSurface: Colors.white,
      ),
      textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyMedium: GoogleFonts.rajdhani(color: Colors.white70, fontSize: 16),
        bodyLarge: GoogleFonts.rajdhani(color: Colors.white, fontSize: 18),
        titleLarge: GoogleFonts.orbitron(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNeon,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: primaryNeon, width: 2),
          ),
          elevation: 10,
          shadowColor: primaryNeon.withValues(alpha: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryNeon, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
      ),
    );
  }
}
