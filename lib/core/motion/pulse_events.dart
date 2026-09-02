sealed class PulseEvent { const PulseEvent(); }
class ActivityCompletedEvent extends PulseEvent { const ActivityCompletedEvent({required this.xpAwarded, required this.newXP, required this.previousStreak, required this.newStreak, required this.newAchievements, required this.leveledUp}); final int xpAwarded, newXP, previousStreak, newStreak; final List<String> newAchievements; final bool leveledUp; }
class StreakIncreasedEvent extends PulseEvent { const StreakIncreasedEvent({required this.previous, required this.current}); final int previous, current; }
class AchievementUnlockedEvent extends PulseEvent { const AchievementUnlockedEvent(this.achievementId); final String achievementId; }
class LevelUpEvent extends PulseEvent { const LevelUpEvent({required this.previousLevel, required this.newLevel}); final int previousLevel, newLevel; }
class DailyChallengeRefreshedEvent extends PulseEvent { const DailyChallengeRefreshedEvent(this.challengeId); final String challengeId; }
class ShareCardGeneratedEvent extends PulseEvent { const ShareCardGeneratedEvent(this.data); final Object data; }
