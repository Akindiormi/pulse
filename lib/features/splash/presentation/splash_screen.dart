import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/motion/pulse_motion_policy.dart';
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
        if (context.mounted && GoRouterState.of(context).uri.path == '/splash') {
          context.go(_route(destination));
        }
      });
    });
    final state = ref.watch(startupControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(PulseSpace.xxxl),
            child: AnimatedOpacity(
              duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 220)),
              opacity: 1,
              child: state.when(
                loading: () => const _SplashMark(),
                data: (_) => const _SplashMark(),
                error: (_, __) => const _SplashMark(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashMark extends StatelessWidget {
  const _SplashMark();
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: PulseColors.accent, borderRadius: BorderRadius.circular(PulseRadius.large)),
            alignment: Alignment.center,
            child: const Text('P', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Color(0xFF1A100D))),
          ),
          const SizedBox(height: PulseSpace.xl),
          Text('PULSE', style: AppTypography.display.copyWith(letterSpacing: -1.8)),
          const SizedBox(height: PulseSpace.sm),
          Text('small actions. real momentum.', textAlign: TextAlign.center, style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}
