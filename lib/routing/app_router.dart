import 'package:go_router/go_router.dart';
import '../app.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const PlaceholderScreen(title: 'PULSE')),
    GoRoute(path: '/onboarding', builder: (_, __) => const PlaceholderScreen(title: 'Welcome to PULSE')),
    GoRoute(path: '/auth', builder: (_, __) => const PlaceholderScreen(title: 'Sign in')),
    GoRoute(path: '/home', builder: (_, __) => const PlaceholderScreen(title: 'Today')),
    GoRoute(path: '/challenge/:id', builder: (_, state) => PlaceholderScreen(title: 'Challenge ${state.pathParameters['id']}')),
    GoRoute(path: '/achievements', builder: (_, __) => const PlaceholderScreen(title: 'Achievements')),
    GoRoute(path: '/profile', builder: (_, __) => const PlaceholderScreen(title: 'Profile')),
    GoRoute(path: '/settings', builder: (_, __) => const PlaceholderScreen(title: 'Settings')),
  ],
);
