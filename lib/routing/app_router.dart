import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/motion/pulse_motion_policy.dart';
import '../features/achievements/presentation/achievements_screen.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/email_verification_screen.dart';
import '../features/challenges/presentation/challenge_detail_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/profile_setup_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shell/presentation/pulse_foundation_placeholder.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/shell/presentation/pulse_shell.dart';

CustomTransitionPage<void> _motionPage({
  required BuildContext context,
  required Widget child,
  required LocalKey key,
  Offset begin = const Offset(0, .04),
  bool scale = false,
}) {
  final duration = PulseMotionPolicy.transitionDuration(context);
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: PulseMotionPolicy.curve(context),
        reverseCurve: PulseMotionPolicy.curve(context, normal: Curves.easeIn),
      );
      final opacity = Tween<double>(begin: 0, end: 1).animate(curved);
      final offset = Tween<Offset>(begin: begin, end: Offset.zero).animate(curved);
      final transformed = scale
          ? ScaleTransition(scale: Tween<double>(begin: .985, end: 1).animate(curved), child: child)
          : child;
      return FadeTransition(opacity: opacity, child: SlideTransition(position: offset, child: transformed));
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
    GoRoute(path: '/verify-email', builder: (_, __) => const EmailVerificationScreen()),
    GoRoute(path: '/profile-setup', builder: (_, __) => const ProfileSetupScreen()),
    ShellRoute(
      builder: (_, state, child) => PulseShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/challenges', builder: (_, __) => const PulseFoundationPlaceholder(title: 'challenges', detail: 'challenge discovery foundation — full screen lands in a later phase.')),
        GoRoute(path: '/achievements', pageBuilder: (context, state) => _motionPage(context: context, key: state.pageKey, child: const AchievementsScreen(), begin: const Offset(.03, 0), scale: true)),
        GoRoute(path: '/profile', pageBuilder: (context, state) => _motionPage(context: context, key: state.pageKey, child: const ProfileScreen(), begin: const Offset(.02, 0))),
      ],
    ),
    GoRoute(path: '/challenge/:id', pageBuilder: (context, state) => _motionPage(context: context, key: state.pageKey, child: ChallengeDetailScreen(challengeId: state.pathParameters['id']!), begin: const Offset(0, .08), scale: true)),
    GoRoute(path: '/settings', pageBuilder: (context, state) => _motionPage(context: context, key: state.pageKey, child: const SettingsScreen(), begin: const Offset(.05, 0))),
  ],
);
