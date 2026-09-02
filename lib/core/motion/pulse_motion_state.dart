import 'package:flutter/material.dart';

enum PulseMotionState {
  entering,
  idle,
  pressed,
  starting,
  loading,
  completing,
  completed,
  alreadyCompleted,
  unavailable,
  error,
}

enum PulseProfileMotionState {
  entering,
  idle,
  pressed,
  editing,
  saving,
  saved,
  error,
}

enum PulseProgressMotionState {
  initial,
  unchanged,
  changed,
  xpGained,
  levelUp,
  full,
}

enum PulseStreakMotionState {
  inactive,
  active,
  increased,
  maintained,
  broken,
  milestone,
}

enum PulseAchievementMotionState {
  none,
  locked,
  unlocked,
  newlyUnlocked,
  milestone,
}

enum PulseCelebrationEvent {
  completion,
  xpGain,
  streakUpdate,
  achievementUnlock,
  levelUp,
}

enum PulseCompletionMotionState {
  pending,
  success,
  alreadyCompleted,
  error,
}

class PulseMotionSlot extends StatelessWidget {
  const PulseMotionSlot({super.key, required this.child, this.alignment = Alignment.center});
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => Align(alignment: alignment, child: child);
}

class PulseMotionBoundary extends StatelessWidget {
  const PulseMotionBoundary({super.key, required this.state, required this.child, this.overlay});
  final PulseMotionState state;
  final Widget child;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          child,
          if (overlay != null) Positioned.fill(child: IgnorePointer(child: overlay!)),
        ],
      );
}
