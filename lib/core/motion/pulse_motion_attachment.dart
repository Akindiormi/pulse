import 'package:flutter/material.dart';

import 'pulse_motion_policy.dart';

class PulseMotionAttachment extends StatelessWidget {
  const PulseMotionAttachment({super.key, required this.intent, required this.state, this.builder, this.child, this.alignment = Alignment.center, this.excludeFromSemantics = true});
  final PulseMotionIntent intent;
  final Enum state;
  final Widget Function(BuildContext context, PulseMotionAttachmentData data)? builder;
  final Widget? child;
  final AlignmentGeometry alignment;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final data = PulseMotionAttachmentData(intent: intent, state: state, reducedMotion: PulseMotionPolicy.isReducedMotion(context), duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 220)));
    final visual = builder?.call(context, data) ?? child;
    if (visual == null) return const SizedBox.shrink();
    final animated = PulseMotionPresentation(state: state, child: Align(alignment: alignment, child: visual));
    return excludeFromSemantics ? ExcludeSemantics(child: animated) : animated;
  }
}

class PulseMotionAttachmentData {
  const PulseMotionAttachmentData({required this.intent, required this.state, required this.reducedMotion, required this.duration});
  final PulseMotionIntent intent;
  final Enum state;
  final bool reducedMotion;
  final Duration duration;
}

enum PulseMotionIntent { splashBrand, onboardingIllustration, onboardingTransition, onboardingCta, homeEntrance, streakReveal, streakChange, xpReveal, xpChange, challengeReveal, challengeInteraction, challengeCompletion, challengeReward, achievementReveal, achievementUnlock, levelUp, profileEntrance, profileSave, settingsChange, navigationTransition, retry, errorRecovery }

class PulseMotionPresentation extends StatefulWidget {
  const PulseMotionPresentation({super.key, required this.state, required this.child});
  final Enum state;
  final Widget child;
  @override
  State<PulseMotionPresentation> createState() => _PulseMotionPresentationState();
}

class _PulseMotionPresentationState extends State<PulseMotionPresentation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  String get _stateName => widget.state.toString().split('.').last;
  bool get _entrance => const {'entering', 'starting', 'unlocking', 'celebrating'}.contains(_stateName);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _controller.forward(); });
  }

  @override
  void didUpdateWidget(covariant PulseMotionPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state && _entrance && !PulseMotionPolicy.isReducedMotion(context)) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = PulseMotionPolicy.isReducedMotion(context);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = reduced ? 1.0 : Curves.easeOutCubic.transform(_controller.value);
        final offset = _entrance && !reduced ? .035 * (1 - t) : 0.0;
        final pressed = _stateName == 'pressed' && !reduced;
        return Opacity(
          opacity: _entrance && !reduced ? t.clamp(.0, 1.0).toDouble() : 1,
          child: Transform.translate(
            offset: Offset(0, 12 * offset),
            child: Transform.scale(scale: pressed ? .985 : 1, child: child),
          ),
        );
      },
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
    final data = PulseMotionAttachmentData(intent: intent, state: state, reducedMotion: PulseMotionPolicy.isReducedMotion(context), duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 220)));
    final overlay = overlayBuilder?.call(context, data);
    return Stack(fit: StackFit.passthrough, children: [
      PulseMotionPresentation(state: state, child: child),
      if (overlay != null && !data.reducedMotion) Positioned.fill(child: IgnorePointer(child: overlay)),
    ]);
  }
}
