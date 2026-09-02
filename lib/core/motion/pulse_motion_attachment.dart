import 'package:flutter/material.dart';

import 'pulse_motion_policy.dart';
import 'pulse_motion_state.dart';

/// A stable visual boundary between product state and future artwork.
///
/// Business/application code supplies [intent] and [state]. The visual layer
/// may later provide [builder] for Rive, illustration, physics, or other
/// custom artwork. No business service owns an animation controller.
class PulseMotionAttachment extends StatelessWidget {
  const PulseMotionAttachment({
    super.key,
    required this.intent,
    required this.state,
    this.builder,
    this.child,
    this.alignment = Alignment.center,
    this.excludeFromSemantics = true,
  });

  final PulseMotionIntent intent;
  final Enum state;
  final Widget Function(BuildContext context, PulseMotionAttachmentData data)? builder;
  final Widget? child;
  final AlignmentGeometry alignment;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final data = PulseMotionAttachmentData(
      intent: intent,
      state: state,
      reducedMotion: PulseMotionPolicy.isReducedMotion(context),
      duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 220)),
    );

    final visual = builder?.call(context, data) ?? child;
    if (visual == null) return const SizedBox.shrink();

    final positioned = Align(alignment: alignment, child: visual);
    return excludeFromSemantics ? ExcludeSemantics(child: positioned) : positioned;
  }
}

class PulseMotionAttachmentData {
  const PulseMotionAttachmentData({
    required this.intent,
    required this.state,
    required this.reducedMotion,
    required this.duration,
  });

  final PulseMotionIntent intent;
  final Enum state;
  final bool reducedMotion;
  final Duration duration;
}

enum PulseMotionIntent {
  splashBrand,
  onboardingIllustration,
  onboardingTransition,
  onboardingCta,
  homeEntrance,
  streakReveal,
  streakChange,
  xpReveal,
  xpChange,
  challengeReveal,
  challengeInteraction,
  challengeCompletion,
  challengeReward,
  achievementReveal,
  achievementUnlock,
  levelUp,
  profileEntrance,
  profileSave,
  settingsChange,
  navigationTransition,
  retry,
  errorRecovery,
}

class PulseMotionScope extends InheritedWidget {
  const PulseMotionScope({super.key, required this.reducedMotion, required super.child});

  final bool reducedMotion;

  static PulseMotionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PulseMotionScope>();

  @override
  bool updateShouldNotify(PulseMotionScope oldWidget) => reducedMotion != oldWidget.reducedMotion;
}

class PulseMotionBoundaryV2 extends StatelessWidget {
  const PulseMotionBoundaryV2({
    super.key,
    required this.intent,
    required this.state,
    required this.child,
    this.overlayBuilder,
  });

  final PulseMotionIntent intent;
  final Enum state;
  final Widget child;
  final Widget Function(BuildContext context, PulseMotionAttachmentData data)? overlayBuilder;

  @override
  Widget build(BuildContext context) {
    final data = PulseMotionAttachmentData(
      intent: intent,
      state: state,
      reducedMotion: PulseMotionPolicy.isReducedMotion(context),
      duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 220)),
    );
    final overlay = overlayBuilder?.call(context, data);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (overlay != null && !data.reducedMotion)
          Positioned.fill(child: IgnorePointer(child: overlay)),
      ],
    );
  }
}
