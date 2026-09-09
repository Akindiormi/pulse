import 'package:flutter/material.dart';

/// Design tokens for Pulse — ported from the nextel-connect design system
/// (deep green / emerald / gold, glass surfaces, Plus Jakarta Sans).
class PulseColors {
  PulseColors._();

  // Brand
  static const accent = Color(0xFF2E8B57); // accentEmerald
  static const accentSoft = Color(0xFF4CA873);
  static const accentDeep = Color(0xFF0D3D2B); // primaryDark
  static const accentTint = Color(0x1F2E8B57);
  static const secondary = Color(0xFF1A5C3A); // secondaryGreen
  static const gold = Color(0xFFD4A017);
  static const goldSoft = Color(0xFFE9C55A);

  // Light surfaces
  static const lightBackground = Color(0xFFF0F4F0);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightElevated = Color(0xFFF4F8F3);
  static const lightText = Color(0xFF0D3D2B);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightTextMuted = Color(0xFF8E978F);

  // Dark surfaces
  static const darkBackground = Color(0xFF0A1A0F);
  static const darkSurface = Color(0xFF0C2015);
  static const darkElevated = Color(0xFF122A1C);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0x99FFFFFF);
  static const darkTextMuted = Color(0x66FFFFFF);

  // Glass (light)
  static const glassCard = Color(0xA6FFFFFF); // white @ 65%
  static const glassCardStrong = Color(0xBFFFFFFF); // white @ 75%
  static const glassBorder = Color(0xCCFFFFFF); // white @ 80%
  static const glassInputFill = Color(0x99FFFFFF); // white @ 60%
  static const glassInputBorder = Color(0x260D3D2B); // green @ 15%
  static const glassTopHighlight = Color(0xE6FFFFFF);

  // Glass (dark)
  static const glassCardDark = Color(0x0FFFFFFF); // white @ 6%
  static const glassCardStrongDark = Color(0x1FFFFFFF);
  static const glassBorderDark = Color(0x1AFFFFFF); // white @ 10%
  static const glassInputFillDark = Color(0x14FFFFFF);
  static const glassInputBorderDark = Color(0x1FFFFFFF);
  static const glassTopHighlightDark = Color(0x1FFFFFFF);

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF2B84B);
  static const error = Color(0xFFE96A6A);
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  // Shadows
  static const shadow = Color(0x140D3D2B); // green @ 8%
  static const buttonShadow = Color(0x4D0D3D2B); // green @ 30%
}

class PulseGradients {
  PulseGradients._();

  static const primaryButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PulseColors.accent, PulseColors.accentDeep],
  );

  static const header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PulseColors.secondary, PulseColors.accentDeep],
  );

  static const progress = LinearGradient(
    colors: [PulseColors.success, PulseColors.accent],
  );

  static const gold = LinearGradient(
    colors: [PulseColors.goldSoft, PulseColors.gold],
  );

  static LinearGradient screen(bool isDark) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [Color(0xFF0C2015), PulseColors.darkBackground]
            : const [Color(0xFFF4F8F3), PulseColors.lightBackground],
      );
}

class PulseSpace {
  PulseSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 40.0;
  static const giant = 48.0;
  static const hero = 64.0;
}

class PulseRadius {
  PulseRadius._();
  static const small = 12.0;
  static const medium = 14.0;
  static const large = 24.0;
  static const hero = 24.0;
  static const button = 16.0;
  static const pill = 100.0;
}

class PulseElevation {
  PulseElevation._();
  static const none = 0.0;
  static const subtle = 2.0;
  static const raised = 6.0;
}
