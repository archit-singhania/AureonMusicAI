import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumTheme {

  static const Color abyssalBackground = Color(0xFF030308);
  static const Color deepSpace = Color(0xFF0B0A1A);
  static const Color neonCyan = Color(0xFF00FFD1);
  static const Color neonMagenta = Color(0xFFFF007F);
  static const Color glassWhite = Color(0x1AFFFFFF);
  
  // Legacy colors to prevent breaking other widgets
  static const Color backgroundBlack = Color(0xFF09090E);
  static const Color surfaceDark = Color(0xFF151522);
  static const Color surfaceElevated = Color(0xFF1E1E2E);
  static const Color accentNeonPurple = Color(0xFFB983FF);
  static const Color accentNeonGreen = Color(0xFF00FFC2);
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFFA0A0B0);


  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: abyssalBackground,
      primaryColor: neonCyan,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonMagenta,
        surface: deepSpace,
        background: abyssalBackground,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceMono(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1),
        titleLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
        labelLarge: GoogleFonts.spaceMono(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: neonCyan),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: glassWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonCyan.withOpacity(0.15),
          foregroundColor: neonCyan,
          shadowColor: neonCyan.withOpacity(0.5),
          elevation: 10,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: neonCyan.withOpacity(0.5))),
          textStyle: GoogleFonts.spaceMono(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: neonMagenta,
        inactiveTrackColor: Colors.white12,
        thumbColor: neonCyan,
        overlayColor: neonCyan.withOpacity(0.2),
        trackHeight: 4.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0, elevation: 8.0),
      ),
    );
  }
}
