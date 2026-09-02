import '../../../models/achievement_model.dart';
import '../data/achievement_definitions.dart';

class AchievementEvaluation {
  const AchievementEvaluation({required this.newAchievements, required this.xpAwarded});
  final List<AchievementRecord> newAchievements;
  final int xpAwarded;
}

class AchievementService {
  const AchievementService({this.definitions = achievementDefinitions});

  final List<AchievementDefinition> definitions;

  AchievementEvaluation evaluate({required int totalActivities, required int currentStreak, required Set<String> completedCategories, required Set<String> unlockedAchievementIds, required DateTime unlockedAt}) {
    final newlyUnlocked = <AchievementRecord>[];
    var xp = 0;
    for (final definition in definitions) {
      if (!definition.active || unlockedAchievementIds.contains(definition.id)) continue;
      final eligible = switch (definition.type) {
        AchievementType.streak => currentStreak >= definition.threshold,
        AchievementType.activityCount => totalActivities >= definition.threshold,
        AchievementType.categoryCount => completedCategories.length >= definition.threshold,
        AchievementType.special => false,
      };
      if (!eligible) continue;
      newlyUnlocked.add(AchievementRecord(achievementId: definition.id, unlockedAt: unlockedAt));
      xp += definition.xpReward;
    }
    return AchievementEvaluation(newAchievements: newlyUnlocked, xpAwarded: xp);
  }
}
