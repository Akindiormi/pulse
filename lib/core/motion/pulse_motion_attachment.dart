import 'package:flutter/material.dart';

import 'pulse_motion_policy.dart';

/// Stable presentation boundary between authoritative product state and motion.
/// The attachment never owns business logic or changes application state.
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
    final animated = PulseMotionPresentation(state: state, child: positioned);
    return excludeFromSemantics ? ExcludeSemantics(child: animated) : animated;
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

class PulseMotionPresentation extends StatelessWidget {
  const PulseMotionPresentation({super.key, required this.state, required this.child});

  final Enum state;
  final Widget child;

  bool _isActive(Enum value) => value.toString().split('.').last == 'pressed';
  bool _isEntering(Enum value) {
    final name = value.toString().split('.').last;
    return name == 'entering' || name == 'starting' || name == 'unlocking' || name == 'celebrating';
  }

  @override
  Widget build(BuildContext context) {
    final reduced = PulseMotionPolicy.isReducedMotion(context);
    final pressed = _isActive(state);
    final entering = _isEntering(state);
    return AnimatedOpacity(
      opacity: 1,
      duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 180)),
      curve: PulseMotionPolicy.curve(context),
      child: AnimatedSlide(
        offset: reduced || !entering ? Offset.zero : const Offset(0, .035),
        duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 280)),
        curve: PulseMotionPolicy.curve(context, normal: Curves.easeOutCubic),
        child: AnimatedScale(
          scale: reduced ? 1 : (pressed ? .985 : 1),
          duration: PulseMotionPolicy.microDuration(context),
          curve: PulseMotionPolicy.curve(context, normal: Curves.easeOutCubic),
          child: child,
        ),
      ),
    );
  }
}

class PulseMotionScope extends InheritedWidget {
  const PulseMotionScope({super.key, required this.reducedMotion, required super.child});
  final bool reducedMotion;
  static PulseMotionScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PulseMotionScope>();
  @override
  bool updateShouldNotify(PulseMotionScope oldWidget) => reducedMotion != oldWidget.reducedMotion;
}

class PulseMotionBoundaryV2 extends StatelessWidget {
  const PulseMotionBoundaryV2({super.key, required this.intent, required this.state, required this.child, this.overlayBuilder});
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
        PulseMotionPresentation(state: state, child: child),
        if (overlay != null && !data.reducedMotion) Positioned.fill(child: IgnorePointer(child: overlay)),
      ],
    );
  }
}
