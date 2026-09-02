import 'pulse_events.dart';
import '../telemetry/analytics_service.dart';

class PulseEventDispatcher {
  const PulseEventDispatcher(this.analytics);
  final AnalyticsService analytics;

  Future<void> dispatch(PulseEvent event) async {
    switch (event) {
      case ActivityCompletedEvent(challengeId: final id):
        await analytics.logChallengeCompleted(id);
      case StreakIncreasedEvent(current: final streak):
        await analytics.logStreakIncreased(streak);
      case AchievementUnlockedEvent(achievementId: final id):
        await analytics.logAchievementUnlocked(id);
      case LevelUpEvent(newLevel: final level):
        await analytics.logLevelUp(level);
      case DailyChallengeRefreshedEvent(challengeId: final id):
        await analytics.logChallengeViewed(id);
      case ShareCardGeneratedEvent():
        await analytics.logShareCardCreated();
    }
  }
}
