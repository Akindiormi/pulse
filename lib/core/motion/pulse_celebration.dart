import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pulse_motion_policy.dart';

/// A short, deterministic celebration driven only by already-authoritative
/// presentation facts. It never computes or mutates progression.
class PulseCompletionCelebration extends StatelessWidget {
  const PulseCompletionCelebration({
    super.key,
    this.hasAchievement = false,
    this.leveledUp = false,
  });

  final bool hasAchievement;
  final bool leveledUp;

  @override
  Widget build(BuildContext context) {
    if (PulseMotionPolicy.isReducedMotion(context)) return const SizedBox.shrink();
    return _PulseCelebrationAnimation(hasAchievement: hasAchievement, leveledUp: leveledUp);
  }
}

class _PulseCelebrationAnimation extends StatefulWidget {
  const _PulseCelebrationAnimation({required this.hasAchievement, required this.leveledUp});
  final bool hasAchievement;
  final bool leveledUp;

  @override
  State<_PulseCelebrationAnimation> createState() => _PulseCelebrationAnimationState();
}

class _PulseCelebrationAnimationState extends State<_PulseCelebrationAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _BurstPainter(progress: _controller.value, intensity: widget.leveledUp ? 1.15 : 1),
            child: const SizedBox.expand(),
          ),
        ),
      );
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({required this.progress, required this.intensity});
  final double progress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()..style = PaintingStyle.fill;
    final eased = Curves.easeOutCubic.transform(progress);
    final opacity = (1 - Curves.easeIn.transform(progress)).clamp(0.0, 1.0);
    final radius = 18 + 58 * eased * intensity;
    const count = 10;
    for (var i = 0; i < count; i++) {
      final angle = (math.pi * 2 * i / count) - math.pi / 2;
      final distance = radius * (0.55 + (i.isEven ? .22 : .08));
      final point = center + Offset(math.cos(angle) * distance, math.sin(angle) * distance);
      final sizeFactor = i.isEven ? 3.0 : 2.2;
      paint.color = Color.lerp(Colors.transparent, const Color(0xFFFF6B4A), opacity * .8)!;
      canvas.drawCircle(point, sizeFactor, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.intensity != intensity;
}
