import 'package:flutter/material.dart';
import '../design/pulse_tokens.dart';
import '../motion/pulse_motion_state.dart';

class PulseCompletionSurface extends StatelessWidget {
  const PulseCompletionSurface({super.key, required this.event, this.xpAwarded = 0, this.motionOverlay});
  final PulseCelebrationEvent event;
  final int xpAwarded;
  final Widget? motionOverlay;

  @override
  Widget build(BuildContext context) => PulseFeedbackSurface(
        semanticLabel: 'challenge completion feedback',
        icon: Icons.check_rounded,
        title: 'nice. you did it.',
        detail: xpAwarded > 0 ? '+$xpAwarded XP' : 'challenge completed',
        overlay: motionOverlay,
      );
}

class PulseLevelUpSurface extends StatelessWidget {
  const PulseLevelUpSurface({super.key, required this.level, this.motionOverlay});
  final int level;
  final Widget? motionOverlay;

  @override
  Widget build(BuildContext context) => PulseFeedbackSurface(
        semanticLabel: 'level up feedback, level $level',
        icon: Icons.auto_awesome_rounded,
        title: 'level up.',
        detail: 'you reached level $level',
        overlay: motionOverlay,
      );
}

class PulseFeedbackSurface extends StatelessWidget {
  const PulseFeedbackSurface({super.key, required this.semanticLabel, required this.icon, required this.title, required this.detail, this.overlay});
  final String semanticLabel;
  final IconData icon;
  final String title;
  final String detail;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        liveRegion: true,
        child: Stack(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(PulseSpace.xxxl), decoration: BoxDecoration(color: PulseColors.accentTint, borderRadius: BorderRadius.circular(PulseRadius.hero)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: PulseColors.accent, size: 32),
            const SizedBox(height: PulseSpace.xl),
            Text(title, style: AppTypography.headline),
            const SizedBox(height: PulseSpace.sm),
            Text(detail, style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
          if (overlay != null) Positioned.fill(child: IgnorePointer(child: overlay!)),
        ]),
      );
}
