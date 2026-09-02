import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/onboarding_controller.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/di/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int page = 0;
  final pages = const [
    ('make today count.', 'Pulse turns small actions into real momentum.'),
    ('one challenge. every day.', 'get a challenge, do it, and build your streak.'),
    ('watch yourself grow.', 'earn XP, unlock achievements, and see how far you can go.'),
  ];

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
    final reducedMotion = ref.watch(pulseMotionPolicyProvider).userReducedMotion;
    final item = pages[page];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PulseSpace.xl, PulseSpace.xl, PulseSpace.xl, PulseSpace.lg),
          child: Column(
            children: [
              Row(children: [
                Text('PULSE', style: AppTypography.title.copyWith(fontWeight: FontWeight.w900)),
                const Spacer(),
                if (page < pages.length - 1) TextButton(onPressed: () => finish(skipped: true), child: const Text('skip')),
              ]),
              Expanded(
                child: AnimatedSwitcher(
                  duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 260),
                  child: KeyedSubtree(
                    key: ValueKey(page),
                    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 104, height: 104, decoration: BoxDecoration(color: PulseColors.accent, borderRadius: BorderRadius.circular(PulseRadius.large)), alignment: Alignment.center, child: Text('${page + 1}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900))),
                      const SizedBox(height: PulseSpace.xxl),
                      Text(item.$1, textAlign: TextAlign.center, style: AppTypography.display),
                      const SizedBox(height: PulseSpace.md),
                      Text(item.$2, textAlign: TextAlign.center, style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ])),
                  ),
                ),
              ),
              Semantics(label: 'onboarding page ${page + 1} of ${pages.length}', child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(pages.length, (index) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Container(width: index == page ? 24 : 8, height: 8, decoration: BoxDecoration(color: index == page ? PulseColors.accent : Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(8)))))),
              const SizedBox(height: PulseSpace.lg),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => page == pages.length - 1 ? finish(skipped: false) : setState(() => page++), child: Text(page == pages.length - 1 ? 'get started' : 'continue'))),
            ],
          ),
        ),
      ),
    );
  }
}
