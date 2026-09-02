import 'package:flutter/material.dart';
import '../design/pulse_tokens.dart';
import '../motion/pulse_motion_policy.dart';
import '../motion/pulse_motion_state.dart';

class PulseStreak extends StatefulWidget {
  const PulseStreak({super.key, required this.current, this.longest = 0, this.state = PulseStreakMotionState.inactive, this.compact = false});
  final int current;
  final int longest;
  final PulseStreakMotionState state;
  final bool compact;

  @override
  State<PulseStreak> createState() => _PulseStreakState();
}

class _PulseStreakState extends State<PulseStreak> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
    if (widget.state == PulseStreakMotionState.increased || widget.state == PulseStreakMotionState.milestone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !PulseMotionPolicy.isReducedMotion(context)) _controller.forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(covariant PulseStreak oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = widget.current != oldWidget.current || widget.state != oldWidget.state;
    if (changed && (widget.state == PulseStreakMotionState.increased || widget.state == PulseStreakMotionState.milestone) && !PulseMotionPolicy.isReducedMotion(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.current > 0 && widget.state != PulseStreakMotionState.broken;
    return Semantics(
      label: '${widget.current} day streak, longest ${widget.longest} days',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: 1 + .035 * Curves.easeOut.transform(_controller.value) * (1 - _controller.value),
          child: child,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 180)),
            width: widget.compact ? 38 : 48,
            height: widget.compact ? 38 : 48,
            decoration: BoxDecoration(color: active ? PulseColors.accentTint : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(PulseRadius.medium)),
            alignment: Alignment.center,
            child: Icon(Icons.local_fire_department_rounded, color: active ? PulseColors.accent : Theme.of(context).colorScheme.onSurfaceVariant, size: widget.compact ? 21 : 25),
          ),
          const SizedBox(width: PulseSpace.md),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.current} day${widget.current == 1 ? '' : 's'}', style: widget.compact ? AppTypography.numberSmall : AppTypography.number),
            Text(active ? 'streak' : 'start again', style: AppTypography.metadata.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ]),
      ),
    );
  }
}
