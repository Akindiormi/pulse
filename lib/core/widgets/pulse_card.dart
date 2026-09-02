import 'package:flutter/material.dart';
import '../design/pulse_tokens.dart';

class PulseCard extends StatelessWidget {
  const PulseCard({super.key, required this.child, this.padding = const EdgeInsets.all(PulseSpace.xxl), this.elevated = false});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: elevated ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(PulseRadius.large),
          boxShadow: elevated
              ? const [BoxShadow(blurRadius: 18, offset: Offset(0, 8), spreadRadius: -10)]
              : const [],
        ),
        child: Padding(padding: padding, child: child),
      );
}

class PulseHeroCard extends StatelessWidget {
  const PulseHeroCard({super.key, required this.child, this.motionOverlay, this.onTap});
  final Widget child;
  final Widget? motionOverlay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.all(PulseSpace.xxxl),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? PulseColors.darkSurface : PulseColors.lightSurface,
        borderRadius: BorderRadius.circular(PulseRadius.hero),
        border: Border.all(color: PulseColors.accent.withValues(alpha: 0.12)),
        boxShadow: const [BoxShadow(blurRadius: 28, offset: Offset(0, 14), spreadRadius: -18)],
      ),
      child: Stack(children: [child, if (motionOverlay != null) Positioned.fill(child: IgnorePointer(child: motionOverlay!))]),
    );
    return onTap == null ? card : Semantics(button: true, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(PulseRadius.hero), child: card));
  }
}
