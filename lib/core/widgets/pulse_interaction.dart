import 'package:flutter/material.dart';

import '../motion/pulse_motion_policy.dart';

/// Lightweight tactile feedback for visual controls. It owns only presentation
/// state; product/business state remains outside this widget.
class PulsePressScale extends StatefulWidget {
  const PulsePressScale({super.key, required this.child, this.scale = .985});

  final Widget child;
  final double scale;

  @override
  State<PulsePressScale> createState() => _PulsePressScaleState();
}

class _PulsePressScaleState extends State<PulsePressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = PulseMotionPolicy.isReducedMotion(context);
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: reduced || !_pressed ? 1 : widget.scale,
        duration: PulseMotionPolicy.microDuration(context),
        curve: PulseMotionPolicy.curve(context, normal: Curves.easeOutCubic),
        child: widget.child,
      ),
    );
  }
}

class PulseHapticIntent {
  const PulseHapticIntent(this.name);
  final String name;

  static const buttonPress = PulseHapticIntent('button_press');
  static const challengeStarted = PulseHapticIntent('challenge_started');
  static const challengeCompleted = PulseHapticIntent('challenge_completed');
  static const achievementUnlocked = PulseHapticIntent('achievement_unlocked');
  static const levelUp = PulseHapticIntent('level_up');
  static const errorRecovery = PulseHapticIntent('error_recovery');
}
