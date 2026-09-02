import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/onboarding_controller.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/motion/pulse_motion_attachment.dart';
import '../../../core/motion/pulse_motion_policy.dart';
import '../../../core/motion/pulse_motion_state.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pulse_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int page = 0;
  final pages = const [
    ('make today count.', 'Pulse turns small actions into real momentum.'),
    ('one challenge. every day.', 'get a challenge, do it, and build your streak.'),
    ('watch yourself grow.', 'earn XP, unlock achievements, and see how far you can go.'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(analyticsServiceProvider).logOnboardingStarted());
  }

  Future<void> finish({required bool skipped}) async {
    if (skipped) {
      await ref.read(onboardingControllerProvider.notifier).skip();
    } else {
      await ref.read(onboardingControllerProvider.notifier).complete();
    }
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final item = pages[page];
    final transition = PulseMotionPolicy.transitionDuration(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PulseSpace.xl, PulseSpace.xl, PulseSpace.xl, PulseSpace.lg),
          child: Column(
            children: [
              Row(
                children: [
                  Text('PULSE', style: AppTypography.title.copyWith(fontWeight: FontWeight.w900)),
                  const Spacer(),
                  if (page < pages.length - 1)
                    PulseButton(variant: PulseButtonVariant.tertiary, label: 'skip', onPressed: () => finish(skipped: true)),
                ],
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: transition,
                  switchInCurve: PulseMotionPolicy.curve(context),
                  switchOutCurve: PulseMotionPolicy.curve(context, normal: Curves.easeIn),
                  child: KeyedSubtree(
                    key: ValueKey(page),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PulseMotionAttachment(
                              intent: PulseMotionIntent.onboardingIllustration,
                              state: PulseMotionState.entering,
                              child: Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(color: PulseColors.accent, borderRadius: BorderRadius.circular(PulseRadius.large)),
                                alignment: Alignment.center,
                                child: Text('${page + 1}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(height: PulseSpace.xxl),
                            Text(item.$1, textAlign: TextAlign.center, style: Theme.of(context).textTheme.displayLarge),
                            const SizedBox(height: PulseSpace.md),
                            Text(item.$2, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                liveRegion: true,
                label: 'onboarding page ${page + 1} of ${pages.length}',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    pages.length,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedContainer(
                        duration: PulseMotionPolicy.microDuration(context),
                        width: index == page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == page ? PulseColors.accent : Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PulseSpace.lg),
              PulseButton(
                expand: true,
                label: page == pages.length - 1 ? 'get started' : 'continue',
                onPressed: () => page == pages.length - 1 ? finish(skipped: false) : setState(() => page++),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
