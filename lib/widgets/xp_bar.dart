import 'package:flutter/material.dart';

class XPBar extends StatelessWidget {
  const XPBar({super.key, required this.xp, required this.nextLevelXP});
  final int xp, nextLevelXP;
  @override
  Widget build(BuildContext context) {
    final progress = nextLevelXP <= 0 ? 0.0 : (xp / nextLevelXP).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text('$xp XP'), const Spacer(), Text('$nextLevelXP XP')]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(minHeight: 8, value: progress)),
    ]);
  }
}
