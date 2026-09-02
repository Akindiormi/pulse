abstract interface class AnalyticsService {
  Future<void> logAppOpen();
  Future<void> logOnboardingStarted();
  Future<void> logOnboardingCompleted();
  Future<void> logOnboardingSkipped();
  Future<void> logAuthScreenViewed();
  Future<void> logSignUpStarted();
  Future<void> logSignUp();
  Future<void> logSignInStarted();
  Future<void> logLogin();
  Future<void> logAuthFailed(String method);
  Future<void> logGoogleSignInStarted();
  Future<void> logGoogleSignInCompleted();
  Future<void> logAppleSignInStarted();
  Future<void> logAppleSignInCompleted();
  Future<void> logEmailVerificationSent();
  Future<void> logEmailVerificationCompleted();
  Future<void> logProfileSetupStarted();
  Future<void> logProfileSetupCompleted();
  Future<void> logChallengeViewed(String challengeId);
  Future<void> logChallengeStarted(String challengeId);
  Future<void> logChallengeCompleted(String challengeId);
  Future<void> logStreakIncreased(int streak);
  Future<void> logAchievementUnlocked(String achievementId);
  Future<void> logLevelUp(int level);
  Future<void> logShareCardCreated();
  Future<void> logNotificationOpened();
}
