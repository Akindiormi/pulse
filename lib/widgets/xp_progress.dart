import 'package:flutter/material.dart';

class XPProgress extends StatelessWidget {
  const XPProgress({super.key, required this.currentXP, required this.level, required this.nextLevelXP});
  final int currentXP, level, nextLevelXP;
  @override
  Widget build(BuildContext context) {
    final start = level <= 1 ? 0 : nextLevelXP - 100;
    final value = nextLevelXP <= start ? 0.0 : ((currentXP - start) / (nextLevelXP - start)).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text('Level $level'), const Spacer(), Text('$currentXP / $nextLevelXP XP')]), const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: value, minHeight: 8))]);
  }
}
