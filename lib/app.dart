import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/di/providers.dart';
import 'routing/app_router.dart';

class PulseApp extends ConsumerWidget {
  const PulseApp({super.key});

  bool _publicPath(String path) => path == '/splash' || path == '/onboarding' || path == '/auth' || path == '/verify-email' || path == '/profile-setup';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      final state = next.valueOrNull;
      if (state == null) return;
      final path = appRouter.state.uri.path;
      if (state.status == AuthStatus.unauthenticated && !_publicPath(path)) {
        appRouter.go('/auth');
      } else if (state.status == AuthStatus.authenticated && (path == '/auth' || path == '/onboarding')) {
        appRouter.go('/splash');
      } else if (state.status == AuthStatus.authenticatedUnverified && path != '/verify-email' && path != '/splash') {
        appRouter.go('/verify-email');
      }
    });
    return MaterialApp.router(
      title: 'PULSE',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: mode,
      routerConfig: appRouter,
    );
  }
}
