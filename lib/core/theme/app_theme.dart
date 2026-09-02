import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../design/pulse_tokens.dart';

class AppTypography {
  static const display = TextStyle(fontSize: 36, height: 1.04, fontWeight: FontWeight.w800, letterSpacing: -1.4);
  static const headline = TextStyle(fontSize: 28, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.8);
  static const title = TextStyle(fontSize: 19, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.15);
  static const body = TextStyle(fontSize: 16, height: 1.45, fontWeight: FontWeight.w400);
  static const label = TextStyle(fontSize: 13, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: 0.1);
  static const metadata = TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w500);
  static const number = TextStyle(fontSize: 32, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -1.0, fontFeatures: [FontFeature.tabularFigures()]);
  static const numberSmall = TextStyle(fontSize: 22, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -0.6, fontFeatures: [FontFeature.tabularFigures()]);
}

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? PulseColors.darkBackground : PulseColors.lightBackground;
  final surface = dark ? PulseColors.darkSurface : PulseColors.lightSurface;
  final elevated = dark ? PulseColors.darkElevated : PulseColors.lightElevated;
  final text = dark ? PulseColors.darkText : PulseColors.lightText;
  final secondary = dark ? PulseColors.darkTextSecondary : PulseColors.lightTextSecondary;
  final muted = dark ? PulseColors.darkTextMuted : PulseColors.lightTextMuted;
  final scheme = ColorScheme.fromSeed(seedColor: PulseColors.accent, brightness: brightness).copyWith(
    primary: PulseColors.accent,
    onPrimary: AppColors.textOnAccent,
    secondary: PulseColors.accentSoft,
    surface: surface,
    onSurface: text,
    surfaceContainerHighest: elevated,
    onSurfaceVariant: secondary,
    error: PulseColors.error,
  );

  final typography = TextTheme(
    displayLarge: AppTypography.display,
    displayMedium: AppTypography.headline,
    displaySmall: AppTypography.headline,
    headlineLarge: AppTypography.display,
    headlineMedium: AppTypography.headline,
    headlineSmall: AppTypography.title,
    titleLarge: AppTypography.title,
    titleMedium: AppTypography.title.copyWith(fontSize: 16, height: 1.3),
    titleSmall: AppTypography.label,
    bodyLarge: AppTypography.body,
    bodyMedium: AppTypography.body.copyWith(fontSize: 14),
    bodySmall: AppTypography.metadata,
    labelLarge: AppTypography.label.copyWith(fontSize: 14),
    labelMedium: AppTypography.label,
    labelSmall: AppTypography.metadata,
  ).apply(bodyColor: text, displayColor: text);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    colorScheme: scheme,
    fontFamily: 'Inter',
    textTheme: typography,
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.large)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: PulseSpace.xl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.medium)),
        textStyle: AppTypography.label.copyWith(fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: PulseSpace.xl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.medium)),
        textStyle: AppTypography.label.copyWith(fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: elevated.withValues(alpha: dark ? 0.55 : 0.7),
      contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpace.lg, vertical: PulseSpace.md),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(PulseRadius.medium), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PulseRadius.medium), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PulseRadius.medium), borderSide: BorderSide(color: PulseColors.accent, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PulseRadius.medium), borderSide: BorderSide(color: PulseColors.error.withValues(alpha: .7))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PulseRadius.medium), borderSide: BorderSide(color: PulseColors.error, width: 1.5)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: surface,
      indicatorColor: PulseColors.accentTint,
      labelTextStyle: WidgetStatePropertyAll(AppTypography.metadata.copyWith(color: secondary)),
    ),
    dividerTheme: DividerThemeData(color: dark ? const Color(0xFF2B2B2F) : const Color(0xFFE9E0D7)),
    iconTheme: IconThemeData(color: secondary),
    extensions: <ThemeExtension<dynamic>>[
      PulseThemeExtension(textSecondary: secondary, textMuted: muted, surface: surface, elevated: elevated),
    ],
  );
}

@immutable
class PulseThemeExtension extends ThemeExtension<PulseThemeExtension> {
  const PulseThemeExtension({required this.textSecondary, required this.textMuted, required this.surface, required this.elevated});
  final Color textSecondary;
  final Color textMuted;
  final Color surface;
  final Color elevated;

  @override
  PulseThemeExtension copyWith({Color? textSecondary, Color? textMuted, Color? surface, Color? elevated}) => PulseThemeExtension(
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        surface: surface ?? this.surface,
        elevated: elevated ?? this.elevated,
      );

  @override
  PulseThemeExtension lerp(covariant PulseThemeExtension? other, double t) {
    if (other == null) return this;
    return PulseThemeExtension(
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      elevated: Color.lerp(elevated, other.elevated, t) ?? elevated,
    );
  }
}
