import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/pulse_tokens.dart';
import 'splash_controller.dart';

class PulseSplashFoundation extends ConsumerStatefulWidget {
  const PulseSplashFoundation({super.key});
  @override ConsumerState<PulseSplashFoundation> createState() => _PulseSplashFoundationState();
}

class _PulseSplashFoundationState extends ConsumerState<PulseSplashFoundation> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<String>>(splashControllerProvider, (_, next) {
      next.whenData((destination) { if (mounted && GoRouterState.of(context).uri.path == '/splash') context.go(destination); });
    });
    return Scaffold(body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(PulseSpace.xxxl), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(color: PulseColors.accent, borderRadius: BorderRadius.circular(PulseRadius.large)), alignment: Alignment.center, child: const Text('P', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Color(0xFF1A100D)))),
      const SizedBox(height: PulseSpace.xl), Text('PULSE', style: AppTypography.display.copyWith(letterSpacing: -1.8)), const SizedBox(height: PulseSpace.sm), Text('small actions. real momentum.', textAlign: TextAlign.center, style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]))));
  }
}
