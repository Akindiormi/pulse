import 'package:flutter/material.dart';

import 'pulse_motion_policy.dart';

/// One short, disposable entrance controller for a visible presentation item.
class PulseStaggered extends StatefulWidget {
  const PulseStaggered({super.key, required this.child, this.index = 0, this.duration = const Duration(milliseconds: 420)});

  final Widget child;
  final int index;
  final Duration duration;

  @override
  State<PulseStaggered> createState() => _PulseStaggeredState();
}

class _PulseStaggeredState extends State<PulseStaggered> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = PulseMotionPolicy.isReducedMotion(context);
    if (reduced) return widget.child;
    final begin = (widget.index * .09).clamp(0.0, .42);
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, 1, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .045), end: Offset.zero).animate(animation),
        child: widget.child,
      ),
    );
  }
}
