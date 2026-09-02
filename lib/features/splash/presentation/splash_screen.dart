import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/motion/pulse_motion_attachment.dart';
import '../../../core/motion/pulse_motion_policy.dart';
import '../../../core/motion/pulse_motion_state.dart';
import '../application/splash_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  String _route(StartupDestination destination) => switch (destination) {
        StartupDestination.onboarding => '/onboarding',
        StartupDestination.auth => '/auth',
        StartupDestination.home => '/home',
        StartupDestination.profileSetup => '/profile-setup',
        StartupDestination.verifyEmail => '/verify-email',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<StartupDestination>>(startupControllerProvider, (_, next) {
      next.whenData((destination) {
        if (context.mounted) context.go(_route(destination));
      });
    }, fireImmediately: true);
    final state = ref.watch(startupControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(PulseSpace.xxxl),
            child: state.when(
              loading: () => const _SplashMark(),
              data: (_) => const _SplashMark(),
              error: (error, _) => _StartupError(
                message: ErrorMessageMapper.from(error, kind: AppErrorKind.network).message,
                onRetry: () => ref.read(startupControllerProvider.notifier).refresh(),
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
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SplashMark(),
          const SizedBox(height: PulseSpace.xxl),
          Semantics(liveRegion: true, child: Text(message, textAlign: TextAlign.center, style: AppTypography.body)),
          const SizedBox(height: PulseSpace.lg),
          FilledButton(onPressed: onRetry, child: const Text('try again')),
        ],
      );
}

class _SplashMark extends StatelessWidget {
  const _SplashMark();
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 180)),
        opacity: 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseMotionAttachment(
              intent: PulseMotionIntent.splashBrand,
              state: PulseMotionState.entering,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: PulseColors.accent, borderRadius: BorderRadius.circular(PulseRadius.large)),
                alignment: Alignment.center,
                child: const Text('P', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Color(0xFF1A100D))),
              ),
            ),
            const SizedBox(height: PulseSpace.xl),
            Text('PULSE', style: Theme.of(context).textTheme.displayLarge?.copyWith(letterSpacing: -1.8)),
            const SizedBox(height: PulseSpace.sm),
            Text('small actions. real momentum.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
}
