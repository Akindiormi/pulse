enum AchievementType { streak, activityCount, categoryCount, special }

class AchievementDefinition {
  const AchievementDefinition({required this.id, required this.name, required this.description, required this.type, required this.threshold, required this.xpReward, required this.iconAsset, this.active = true});
  final String id, name, description, iconAsset;
  final AchievementType type;
  final int threshold, xpReward;
  final bool active;
}

class AchievementRecord {
  const AchievementRecord({required this.achievementId, required this.unlockedAt});
  final String achievementId;
  final DateTime unlockedAt;
}
