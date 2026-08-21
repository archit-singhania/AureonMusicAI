import 'package:flutter/material.dart';

class PremiumTheme {
  // Deep Obsidian Studio Palette (Logic Pro / Ableton style)
  static const Color backgroundBlack = Color(0xFF0D0D0E);
  static const Color surfaceDark = Color(0xFF18181A);
  static const Color surfaceElevated = Color(0xFF232326);
  
  static const Color accentNeonGreen = Color(0xFF00FF7F); // subtle
  static const Color accentNeonPurple = Color(0xFFB400FF);
  static const Color textPrimary = Color(0xFFEDEDED);
  static const Color textSecondary = Color(0xFF8A8A8E);

  static ThemeData get themeData {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundBlack,
      primaryColor: accentNeonPurple,
      fontFamily: 'Inter', // Assuming Inter or similar sans-serif
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: accentNeonPurple,
        secondary: accentNeonGreen,
        surface: surfaceDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentNeonPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A2A2E), width: 1),
        ),
      ),
    );
  }
}

