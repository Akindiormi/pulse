import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  static const display = TextStyle(fontSize: 34, height: 1.08, fontWeight: FontWeight.w800, letterSpacing: -1.0);
  static const headline = TextStyle(fontSize: 25, height: 1.15, fontWeight: FontWeight.w750, letterSpacing: -0.5);
  static const title = TextStyle(fontSize: 18, height: 1.25, fontWeight: FontWeight.w700);
  static const body = TextStyle(fontSize: 16, height: 1.45, fontWeight: FontWeight.w400);
  static const label = TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w650, letterSpacing: 0.2);
  static const metadata = TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w500, letterSpacing: 0.1);
}

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: brightness,
    surface: dark ? AppColors.darkSurface : AppColors.lightSurface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? AppColors.darkBackground : AppColors.lightBackground,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge: AppTypography.display,
      headlineMedium: AppTypography.headline,
      titleLarge: AppTypography.title,
      bodyLarge: AppTypography.body,
      labelLarge: AppTypography.label,
      bodySmall: AppTypography.metadata,
    ).apply(bodyColor: dark ? Colors.white : const Color(0xFF201C19), displayColor: dark ? Colors.white : const Color(0xFF201C19)),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: dark ? AppColors.darkSurface : AppColors.lightSurface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.18),
    ),
  );
}
