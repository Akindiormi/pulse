import 'package:flutter/material.dart';
import '../design/pulse_tokens.dart';
import '../motion/pulse_motion_state.dart';

class PulseStreak extends StatelessWidget {
  const PulseStreak({super.key, required this.current, this.longest = 0, this.state = PulseStreakMotionState.inactive, this.compact = false});
  final int current;
  final int longest;
  final PulseStreakMotionState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = current > 0 && state != PulseStreakMotionState.broken;
    return Semantics(
      label: '$current day streak, longest $longest days',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: compact ? 38 : 48,
          height: compact ? 38 : 48,
          decoration: BoxDecoration(color: active ? PulseColors.accentTint : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(PulseRadius.medium)),
          alignment: Alignment.center,
          child: Icon(Icons.local_fire_department_rounded, color: active ? PulseColors.accent : Theme.of(context).colorScheme.onSurfaceVariant, size: compact ? 21 : 25),
        ),
        const SizedBox(width: PulseSpace.md),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$current day${current == 1 ? '' : 's'}', style: compact ? AppTypography.numberSmall : AppTypography.number),
          Text(active ? 'streak' : 'start again', style: AppTypography.metadata.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ]),
    );
  }
}
