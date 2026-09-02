import 'package:flutter/material.dart';
import '../design/pulse_tokens.dart';
import '../motion/pulse_motion_policy.dart';
import '../motion/pulse_motion_state.dart';
import '../theme/app_theme.dart';

class PulseXpProgress extends StatelessWidget {
  const PulseXpProgress({super.key, required this.currentXp, required this.nextLevelXp, this.level = 1, this.motionState = PulseProgressMotionState.initial, this.showValues = true});
  final int currentXp;
  final int nextLevelXp;
  final int level;
  final PulseProgressMotionState motionState;
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    final max = nextLevelXp <= 0 ? 1 : nextLevelXp;
    final value = (currentXp / max).clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: 'Level $level, $currentXp of $nextLevelXp XP',
      value: '${(value * 100).round()} percent',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (showValues) Row(children: [Text('level $level', style: AppTypography.label), const Spacer(), Text('$currentXp / $nextLevelXp XP', style: AppTypography.metadata)]),
        if (showValues) const SizedBox(height: PulseSpace.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(PulseRadius.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 420)),
            curve: Curves.easeOutCubic,
            builder: (_, progress, __) => LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(PulseColors.accent),
            ),
          ),
        ),
      ]),
    );
  }
}
