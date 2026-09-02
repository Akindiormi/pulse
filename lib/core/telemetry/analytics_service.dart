abstract interface class AnalyticsService {
  Future<void> logAppOpen();
  Future<void> logOnboardingCompleted();
  Future<void> logSignUp();
  Future<void> logLogin();
  Future<void> logChallengeViewed(String challengeId);
  Future<void> logChallengeStarted(String challengeId);
  Future<void> logChallengeCompleted(String challengeId);
  Future<void> logStreakIncreased(int streak);
  Future<void> logAchievementUnlocked(String achievementId);
  Future<void> logLevelUp(int level);
  Future<void> logShareCardCreated();
  Future<void> logNotificationOpened();
}
