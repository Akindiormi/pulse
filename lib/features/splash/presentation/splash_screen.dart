import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/pulse_tokens.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_colors.dart';
import '../application/splash_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  String _route(StartupDestination destination) => switch (destination) {
        StartupDestination.onboarding => '/onboarding',
        StartupDestination.auth => '/auth',
        StartupDestination.home => '/home',
        StartupDestination.profileSetup => '/profile-setup',
        StartupDestination.firstFocus => '/first-focus',
        StartupDestination.firstWin => '/first-win',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(startupControllerProvider);

    ref.listen<AsyncValue<StartupDestination>>(
      startupControllerProvider,
      (_, next) => next.whenData((destination) {
        if (context.mounted) {
          context.go(_route(destination));
        }
      }),
      fireImmediately: true,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(PulseSpace.xxxl),
            child: state.when(
              loading: () => const _SplashMark(),
              data: (_) => const _SplashMark(),
              error: (error, _) => _StartupError(
                message: ErrorMessageMapper.from(
                  error,
                  kind: AppErrorKind.network,
                ).message,
                onRetry: () => ref
                    .read(startupControllerProvider.notifier)
                    .refresh(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SplashMark(),
        const SizedBox(height: PulseSpace.xxl),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: PulseSpace.lg),
        FilledButton(
          onPressed: onRetry,
          child: const Text('try again'),
        ),
      ],
    );
  }
}

class _SplashMark extends StatelessWidget {
  const _SplashMark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(PulseRadius.large),
          ),
          alignment: Alignment.center,
          child: const Text(
            'P',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: AppColors.textOnAccent,
            ),
          ),
        ),
        const SizedBox(height: PulseSpace.xl),
        Text(
          'PULSE',
          style: theme.textTheme.displayLarge?.copyWith(letterSpacing: -1.8),
        ),
        const SizedBox(height: PulseSpace.sm),
        Text(
          'plan. focus. progress.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
