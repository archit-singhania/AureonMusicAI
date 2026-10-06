import 'package:flutter/material.dart';

enum StudioPalette {
  iris(
    'Iris',
    'Pearl, iris and warm coral',
    Color(0xFF6850AD),
    Color(0xFFC5B3FF),
  ),
  copper(
    'Copper',
    'Pearl, copper and soft sage',
    Color(0xFF8A4D38),
    Color(0xFFF1B69D),
  ),
  tide(
    'Tide',
    'Pearl, sea glass and muted rose',
    Color(0xFF35665E),
    Color(0xFFA0D8CA),
  );

  const StudioPalette(this.label, this.description, this.light, this.dark);
  final String label, description;
  final Color light, dark;
}

/// Quiet tonal content surfaces, with richer colour reserved for interaction.
abstract final class StudioTheme {
  static const iris = Color(0xFF6850AD);
  static const coral = Color(0xFFC97568);
  static const pearl = Color(0xFFF8F5F0);
  static const ink = Color(0xFF12151E);

  static ThemeData create(
    Brightness brightness, {
    bool highContrast = false,
    StudioPalette palette = StudioPalette.iris,
  }) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? palette.dark : palette.light;
    final secondary = dark ? const Color(0xFFF0AD9E) : const Color(0xFF9B4F43);
    final surface = dark ? const Color(0xFF1C202C) : const Color(0xFFFEFCF8);
    final text = dark ? const Color(0xFFF4F0F9) : const Color(0xFF252331);
    var scheme =
        ColorScheme.fromSeed(
          seedColor: palette.light,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: dark ? const Color(0xFF281B4C) : Colors.white,
          primaryContainer: dark
              ? const Color(0xFF302847)
              : const Color(0xFFEAE2F6),
          onPrimaryContainer: dark
              ? const Color(0xFFEDE3FF)
              : const Color(0xFF423060),
          secondary: secondary,
          onSecondary: dark ? const Color(0xFF44221C) : Colors.white,
          secondaryContainer: dark
              ? const Color(0xFF382B2D)
              : const Color(0xFFF5E4DC),
          onSecondaryContainer: dark
              ? const Color(0xFFFFDBD1)
              : const Color(0xFF713A30),
          tertiary: dark ? const Color(0xFF9CCFC0) : const Color(0xFF346A5C),
          surface: surface,
          surfaceContainerLowest: dark ? ink : const Color(0xFFF6F1EB),
          surfaceContainerLow: dark
              ? const Color(0xFF202431)
              : const Color(0xFFF9F5F0),
          surfaceContainer: dark
              ? const Color(0xFF252A38)
              : const Color(0xFFF2ECE6),
          surfaceContainerHigh: dark
              ? const Color(0xFF2C3141)
              : const Color(0xFFEDE6E0),
          surfaceContainerHighest: dark
              ? const Color(0xFF343A4C)
              : const Color(0xFFE7DFD9),
          onSurface: text,
          onSurfaceVariant: dark
              ? const Color(0xFFBBB8CA)
              : const Color(0xFF6C6474),
          outline: dark ? const Color(0xFF9289A6) : const Color(0xFF93869B),
          outlineVariant: dark
              ? const Color(0xFF3B3D50)
              : const Color(0xFFE4DCE7),
          error: dark ? const Color(0xFFFFB4AC) : const Color(0xFFAA342E),
        );
    if (palette != StudioPalette.iris) {
      scheme = scheme.copyWith(
        onPrimary: dark ? const Color(0xFF202620) : Colors.white,
        primaryContainer: Color.alphaBlend(
          primary.withValues(alpha: dark ? .16 : .13),
          surface,
        ),
        onPrimaryContainer: dark ? scheme.onSurface : palette.light,
        secondary: palette == StudioPalette.copper
            ? (dark ? const Color(0xFFB5CDB0) : const Color(0xFF4C6547))
            : (dark ? const Color(0xFFE5B7C8) : const Color(0xFF86516A)),
        secondaryContainer: palette == StudioPalette.copper
            ? (dark ? const Color(0xFF2B342D) : const Color(0xFFE5EBDD))
            : (dark ? const Color(0xFF382E3A) : const Color(0xFFF2E2EB)),
        onSecondary: dark ? const Color(0xFF282128) : Colors.white,
        onSecondaryContainer: dark ? scheme.onSurface : const Color(0xFF3D3545),
      );
    }
    if (highContrast) {
      scheme = scheme.copyWith(
        onSurface: dark ? Colors.white : const Color(0xFF111117),
        onSurfaceVariant: dark
            ? const Color(0xFFE4E0EC)
            : const Color(0xFF3D3545),
        outline: dark ? const Color(0xFFCFCDD7) : const Color(0xFF4C4657),
        outlineVariant: dark
            ? const Color(0xFF91899D)
            : const Color(0xFF8B7F94),
      );
    }

    const numerals = [FontFeature.tabularFigures()];
    final typography = ThemeData(brightness: brightness).textTheme
        .copyWith(
          displayLarge: TextStyle(
            fontSize: 56,
            height: 1.08,
            fontWeight: FontWeight.w600,
            letterSpacing: -2.8,
            color: scheme.onSurface,
          ),
          displayMedium: TextStyle(
            fontSize: 36,
            height: 1.14,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.6,
            color: scheme.onSurface,
          ),
          displaySmall: TextStyle(
            fontSize: 30,
            height: 1.18,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.1,
            color: scheme.onSurface,
          ),
          headlineLarge: TextStyle(
            fontSize: 30,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: -1,
            color: scheme.onSurface,
          ),
          headlineMedium: TextStyle(
            fontSize: 26,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -.8,
            color: scheme.onSurface,
          ),
          headlineSmall: TextStyle(
            fontSize: 24,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -.6,
            color: scheme.onSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -.55,
            color: scheme.onSurface,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w600,
            letterSpacing: -.2,
            color: scheme.onSurface,
          ),
          titleSmall: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.6,
            letterSpacing: -.15,
            color: scheme.onSurface,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.55,
            letterSpacing: -.1,
            color: scheme.onSurface,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: scheme.onSurfaceVariant,
          ),
          labelLarge: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: -.1,
            color: scheme.onSurface,
            fontFeatures: numerals,
          ),
          labelMedium: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: .3,
            color: scheme.onSurfaceVariant,
            fontFeatures: numerals,
          ),
          labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: .7,
            color: scheme.onSurfaceVariant,
            fontFeatures: numerals,
          ),
        )
        .apply(fontFamily: 'Manrope', fontFamilyFallback: const ['Inter']);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? ink : pearl,
      fontFamily: 'Manrope',
      fontFamilyFallback: const ['Inter'],
      textTheme: typography,
      dividerColor: scheme.outlineVariant,
      splashFactory: InkRipple.splashFactory,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: typography.bodySmall,
        hintStyle: typography.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: typography.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: typography.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: typography.labelLarge),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        labelStyle: typography.bodySmall?.copyWith(color: scheme.onSurface),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => typography.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFE9E3F0) : const Color(0xFF292331),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: typography.bodySmall?.copyWith(
          color: dark ? ink : Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.outlineVariant,
        thumbColor: scheme.primary,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
    );
  }
}
