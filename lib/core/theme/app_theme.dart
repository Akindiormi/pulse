import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import '../design/pulse_tokens.dart';
import '../design/pulse_icons.dart';

/// Typography ported from nextel-connect (Plus Jakarta Sans, tight tracking
/// on display/heading roles, comfortable line height on body/label).
class AppTypography {
  static const display = TextStyle(fontSize: 42, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -1.0);
  static const headline = TextStyle(fontSize: 32, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -1.0);
  static const title = TextStyle(fontSize: 21, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const body = TextStyle(fontSize: 17, height: 1.6, fontWeight: FontWeight.w400);
  static const bodySmall = TextStyle(fontSize: 15, height: 1.6, fontWeight: FontWeight.w400);
  static const label = TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: 0.3);
  static const metadata = TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w500, letterSpacing: 0.3);
  static const number = TextStyle(fontSize: 38, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -1.0, fontFeatures: [FontFeature.tabularFigures()]);
  static const numberSmall = TextStyle(fontSize: 24, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -0.5, fontFeatures: [FontFeature.tabularFigures()]);
}

ThemeData buildAppTheme(Brightness brightness, {bool useGoogleFonts = true}) {
  final dark = brightness == Brightness.dark;
  final background = dark ? PulseColors.darkBackground : PulseColors.lightBackground;
  final surface = dark ? PulseColors.darkSurface : PulseColors.lightSurface;
  final elevated = dark ? PulseColors.darkElevated : PulseColors.lightElevated;
  final text = dark ? PulseColors.darkText : PulseColors.lightText;
  final secondary = dark ? PulseColors.darkTextSecondary : PulseColors.lightTextSecondary;
  final muted = dark ? PulseColors.darkTextMuted : PulseColors.lightTextMuted;
  final card = dark ? PulseColors.glassCardDark : PulseColors.glassCard;
  final cardStrong = dark ? PulseColors.glassCardStrongDark : PulseColors.glassCardStrong;
  final glassBorder = dark ? PulseColors.glassBorderDark : PulseColors.glassBorder;
  final inputFill = dark ? PulseColors.glassInputFillDark : PulseColors.glassInputFill;
  final inputBorder = dark ? PulseColors.glassInputBorderDark : PulseColors.glassInputBorder;
  final topHighlight = dark ? PulseColors.glassTopHighlightDark : PulseColors.glassTopHighlight;

  final scheme = ColorScheme.fromSeed(seedColor: PulseColors.accent, brightness: brightness).copyWith(
    primary: PulseColors.accent,
    onPrimary: AppColors.textOnAccent,
    secondary: PulseColors.secondary,
    surface: surface,
    onSurface: text,
    surfaceContainerHighest: elevated,
    onSurfaceVariant: secondary,
    error: PulseColors.error,
  );

  final baseTypography = TextTheme(
    displayLarge: AppTypography.display,
    displayMedium: AppTypography.headline,
    displaySmall: AppTypography.headline,
    headlineLarge: AppTypography.display,
    headlineMedium: AppTypography.headline,
    headlineSmall: AppTypography.title,
    titleLarge: AppTypography.title,
    titleMedium: AppTypography.title.copyWith(fontSize: 17),
    titleSmall: AppTypography.label,
    bodyLarge: AppTypography.body,
    bodyMedium: AppTypography.bodySmall,
    bodySmall: AppTypography.metadata,
    labelLarge: AppTypography.label.copyWith(fontSize: 15),
    labelMedium: AppTypography.label,
    labelSmall: AppTypography.metadata,
  );
  final typography = (useGoogleFonts ? GoogleFonts.plusJakartaSansTextTheme(baseTypography) : baseTypography).apply(
    bodyColor: text,
    displayColor: text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    colorScheme: scheme,
    fontFamily: useGoogleFonts ? GoogleFonts.plusJakartaSans().fontFamily : null,
    textTheme: typography,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: text,
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PulseRadius.large),
        side: BorderSide(color: glassBorder, width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: PulseSpace.xl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.button)),
        textStyle: typography.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: PulseSpace.xl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulseRadius.button)),
        textStyle: typography.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: PulseSpace.lg, vertical: PulseSpace.lg),
      labelStyle: typography.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      hintStyle: typography.bodyMedium?.copyWith(color: secondary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(PulseRadius.medium), borderSide: BorderSide(color: inputBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PulseRadius.medium), borderSide: BorderSide(color: inputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PulseRadius.medium), borderSide: BorderSide(color: PulseColors.accent, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PulseRadius.medium), borderSide: BorderSide(color: PulseColors.error.withValues(alpha: .7))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(PulseRadius.medium), borderSide: BorderSide(color: PulseColors.error, width: 1.5)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      elevation: 0,
      backgroundColor: surface,
      indicatorColor: PulseColors.accentTint,
      labelTextStyle: WidgetStatePropertyAll(typography.labelMedium?.copyWith(color: secondary)),
    ),
    dividerTheme: DividerThemeData(color: glassBorder),
    iconTheme: IconThemeData(color: secondary, size: PulseIconSize.md),
    extensions: <ThemeExtension<dynamic>>[
      PulseThemeExtension(
        textSecondary: secondary,
        textMuted: muted,
        surface: surface,
        elevated: elevated,
        card: card,
        cardStrong: cardStrong,
        glassBorder: glassBorder,
        topHighlight: topHighlight,
      ),
    ],
  );
}

@immutable
class PulseThemeExtension extends ThemeExtension<PulseThemeExtension> {
  const PulseThemeExtension({
    required this.textSecondary,
    required this.textMuted,
    required this.surface,
    required this.elevated,
    required this.card,
    required this.cardStrong,
    required this.glassBorder,
    required this.topHighlight,
  });

  final Color textSecondary;
  final Color textMuted;
  final Color surface;
  final Color elevated;
  final Color card;
  final Color cardStrong;
  final Color glassBorder;
  final Color topHighlight;

  @override
  PulseThemeExtension copyWith({
    Color? textSecondary,
    Color? textMuted,
    Color? surface,
    Color? elevated,
    Color? card,
    Color? cardStrong,
    Color? glassBorder,
    Color? topHighlight,
  }) =>
      PulseThemeExtension(
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        surface: surface ?? this.surface,
        elevated: elevated ?? this.elevated,
        card: card ?? this.card,
        cardStrong: cardStrong ?? this.cardStrong,
        glassBorder: glassBorder ?? this.glassBorder,
        topHighlight: topHighlight ?? this.topHighlight,
      );

  @override
  PulseThemeExtension lerp(covariant PulseThemeExtension? other, double t) {
    if (other == null) return this;
    return PulseThemeExtension(
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      elevated: Color.lerp(elevated, other.elevated, t) ?? elevated,
      card: Color.lerp(card, other.card, t) ?? card,
      cardStrong: Color.lerp(cardStrong, other.cardStrong, t) ?? cardStrong,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      topHighlight: Color.lerp(topHighlight, other.topHighlight, t) ?? topHighlight,
    );
  }
}
