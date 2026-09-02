import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/shell/presentation/pulse_foundation_placeholder.dart';
import '../features/splash/pulse_splash_foundation.dart';
import '../features/shell/presentation/pulse_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const PulseSplashFoundation()),
    GoRoute(path: '/onboarding', builder: (_, __) => const PulseFoundationPlaceholder(title: 'welcome', detail: 'onboarding foundation — product flow lands in a later phase.')),
    GoRoute(path: '/auth', builder: (_, __) => const PulseFoundationPlaceholder(title: 'sign in', detail: 'authentication foundation — product flow lands in a later phase.')),
    ShellRoute(
      builder: (_, state, child) => PulseShell(currentPath: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/challenges', builder: (_, __) => const PulseFoundationPlaceholder(title: 'challenges', detail: 'challenge discovery foundation — full screen lands in a later phase.')),
        GoRoute(path: '/achievements', builder: (_, __) => const PulseFoundationPlaceholder(title: 'achievements', detail: 'achievement experience lands in a later phase.')),
        GoRoute(path: '/profile', builder: (_, __) => const PulseFoundationPlaceholder(title: 'profile', detail: 'profile experience lands in a later phase.')),
      ],
    ),
    GoRoute(path: '/challenge/:id', builder: (_, state) => PulseFoundationPlaceholder(title: 'challenge', detail: 'challenge ${state.pathParameters['id']} — full experience lands in a later phase.')),
    GoRoute(path: '/settings', builder: (_, __) => const PulseFoundationPlaceholder(title: 'settings', detail: 'settings experience lands in a later phase.')),
  ],
);
