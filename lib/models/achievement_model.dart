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

  Map<String, dynamic> toMap() => {'achievementId': achievementId, 'unlockedAt': unlockedAt};

  factory AchievementRecord.fromMap(String id, Map<String, dynamic> map) => AchievementRecord(
        achievementId: map['achievementId'] as String? ?? id,
        unlockedAt: _date(map['unlockedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.tryParse(value.toString());
    }
  }
}
