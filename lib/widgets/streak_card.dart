import 'package:flutter/material.dart';

class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.currentStreak, required this.longestStreak});
  final int currentStreak, longestStreak;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
    const Icon(Icons.local_fire_department_rounded), const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$currentStreak day streak', style: Theme.of(context).textTheme.titleLarge), Text('best: $longestStreak days', style: Theme.of(context).textTheme.bodySmall)]),
  ])));
}
