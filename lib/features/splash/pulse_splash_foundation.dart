import 'package:flutter/material.dart';
import '../../core/design/pulse_tokens.dart';

class PulseSplashFoundation extends StatelessWidget {
  const PulseSplashFoundation({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(PulseSpace.xxxl), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 72, height: 72, decoration: BoxDecoration(color: PulseColors.accent, borderRadius: BorderRadius.circular(PulseRadius.large)), alignment: Alignment.center, child: const Text('P', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Color(0xFF1A100D)))),
          const SizedBox(height: PulseSpace.xl),
          Text('PULSE', style: AppTypography.display.copyWith(letterSpacing: -1.8)),
          const SizedBox(height: PulseSpace.sm),
          Text('small actions. real momentum.', textAlign: TextAlign.center, style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]))),
      );
}
