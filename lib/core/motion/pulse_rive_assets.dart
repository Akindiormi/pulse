/// Canonical locations for future Pulse Rive artwork.
///
/// These paths are intentionally not treated as available until the matching
/// `.riv` file is supplied. Screens should keep a functional Flutter fallback.
abstract final class PulseRiveAssets {
  static const splash = 'assets/rive/splash/pulse_splash.riv';
  static const onboarding = 'assets/rive/onboarding/onboarding.riv';
  static const auth = 'assets/rive/auth/auth.riv';
  static const challenge = 'assets/rive/challenge/challenge.riv';
  static const progression = 'assets/rive/progression/progression.riv';
  static const achievements = 'assets/rive/achievements/achievements.riv';
  static const profile = 'assets/rive/profile/profile.riv';
  static const navigation = 'assets/rive/navigation/navigation.riv';
}
