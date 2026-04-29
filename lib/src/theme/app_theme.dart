import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF0D9488);

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF2DD4BF),
        secondary: const Color(0xFFFBBF24),
        tertiary: const Color(0xFFF87171),
        surface: const Color(0xFF111827),
        surfaceContainerHighest: const Color(0xFF1F2937),
        onSurface: Colors.white,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFF030712),
    textTheme: Typography.whiteMountainView.copyWith(
      headlineMedium: const TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: const TextStyle(fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontWeight: FontWeight.w600),
      bodyMedium: const TextStyle(height: 1.35),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF111827),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF2DD4BF), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1E293B),
      selectedColor: const Color(0xFF0F766E),
      disabledColor: const Color(0xFF1F2937),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );
}
