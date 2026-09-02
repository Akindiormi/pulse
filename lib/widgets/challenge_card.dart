import 'package:flutter/material.dart';
import '../models/challenge_model.dart';
import 'app_button.dart';

class ChallengeCard extends StatelessWidget {
  const ChallengeCard({super.key, required this.challenge, this.completed = false, this.onComplete});
  final Challenge challenge;
  final bool completed;
  final VoidCallback? onComplete;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(challenge.category.name.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 10), Text(challenge.title, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 10),
      Text(challenge.description, style: Theme.of(context).textTheme.bodyLarge), const SizedBox(height: 18),
      Row(children: [Text('${challenge.xpReward} XP'), const Spacer(), Text('${challenge.estimatedMinutes} min')]),
      if (onComplete != null) ...[const SizedBox(height: 18), AppButton(label: completed ? 'Completed' : 'Complete challenge', onPressed: completed ? null : onComplete)],
    ])),
  );
}
