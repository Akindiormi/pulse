sealed class PulseEvent {
  const PulseEvent();
  String get analyticsName;
}

class ActivityCompletedEvent extends PulseEvent {
  const ActivityCompletedEvent({required this.challengeId, required this.xpAwarded, required this.newXP, required this.previousStreak, required this.newStreak, required this.newAchievements, required this.leveledUp});
  final String challengeId;
  final int xpAwarded, newXP, previousStreak, newStreak;
  final List<String> newAchievements;
  final bool leveledUp;
  @override String get analyticsName => 'challenge_completed';
}

class StreakIncreasedEvent extends PulseEvent {
  const StreakIncreasedEvent({required this.previous, required this.current});
  final int previous, current;
  @override String get analyticsName => 'streak_increased';
}

class AchievementUnlockedEvent extends PulseEvent {
  const AchievementUnlockedEvent(this.achievementId);
  final String achievementId;
  @override String get analyticsName => 'achievement_unlocked';
}

class LevelUpEvent extends PulseEvent {
  const LevelUpEvent({required this.previousLevel, required this.newLevel});
  final int previousLevel, newLevel;
  @override String get analyticsName => 'level_up';
}

class DailyChallengeRefreshedEvent extends PulseEvent {
  const DailyChallengeRefreshedEvent(this.challengeId);
  final String challengeId;
  @override String get analyticsName => 'challenge_viewed';
}

class ShareCardGeneratedEvent extends PulseEvent {
  const ShareCardGeneratedEvent(this.data);
  final Object data;
  @override String get analyticsName => 'share_card_created';
}
