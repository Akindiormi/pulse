import 'package:flutter/material.dart';

enum PulseMotionState { entering, idle, pressed, loading, completing, completed, unavailable, error }
enum PulseProgressMotionState { initial, changed, xpGained, levelUp, full }
enum PulseStreakMotionState { inactive, active, increased, maintained, broken, milestone }
enum PulseAchievementMotionState { locked, unlocked, newlyUnlocked, milestone }
enum PulseCelebrationEvent { completion, xpGain, streakUpdate, achievementUnlock, levelUp }

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
