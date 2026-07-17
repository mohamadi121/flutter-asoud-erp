import 'package:flutter/material.dart';

import 'asoud_colors.dart';

abstract final class AsoudTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AsoudColors.primary,
      surface: AsoudColors.surface,
    );
    final textTheme = ThemeData.light().textTheme.apply(
          fontFamily: 'Vazirmatn',
          bodyColor: AsoudColors.text,
          displayColor: AsoudColors.text,
        );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Vazirmatn',
      colorScheme: scheme,
      scaffoldBackgroundColor: AsoudColors.background,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AsoudColors.background,
        foregroundColor: AsoudColors.text,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AsoudColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AsoudColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AsoudColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AsoudColors.primary.withValues(alpha: .38);
            }
            if (states.contains(WidgetState.pressed)) {
              return AsoudColors.primaryDark;
            }
            return AsoudColors.primary;
          }),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          textStyle: WidgetStatePropertyAll(
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
      cardTheme: CardThemeData(
        color: AsoudColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AsoudColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFEAF2FF),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
    );
  }
}
