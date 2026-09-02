import 'package:firebase_analytics/firebase_analytics.dart';
import 'analytics_service.dart';

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService(this.analytics);
  final FirebaseAnalytics analytics;

  Future<void> _event(String name, [Map<String, Object> parameters = const {}]) => analytics.logEvent(name: name, parameters: parameters);

  @override Future<void> logAppOpen() => _event('app_open');
  @override Future<void> logOnboardingStarted() => _event('onboarding_started');
  @override Future<void> logOnboardingCompleted() => _event('onboarding_completed');
  @override Future<void> logOnboardingSkipped() => _event('onboarding_skipped');
  @override Future<void> logAuthScreenViewed() => _event('auth_screen_viewed');
  @override Future<void> logSignUpStarted() => _event('sign_up_started');
  @override Future<void> logSignUp() => _event('sign_up_completed');
  @override Future<void> logSignInStarted() => _event('sign_in_started');
  @override Future<void> logLogin() => _event('sign_in_completed');
  @override Future<void> logAuthFailed(String method) => _event('auth_failed', {'method': method});
  @override Future<void> logGoogleSignInStarted() => _event('google_sign_in_started');
  @override Future<void> logGoogleSignInCompleted() => _event('google_sign_in_completed');
  @override Future<void> logAppleSignInStarted() => _event('apple_sign_in_started');
  @override Future<void> logAppleSignInCompleted() => _event('apple_sign_in_completed');
  @override Future<void> logEmailVerificationSent() => _event('email_verification_sent');
  @override Future<void> logEmailVerificationCompleted() => _event('email_verification_completed');
  @override Future<void> logProfileSetupStarted() => _event('profile_setup_started');
  @override Future<void> logProfileSetupCompleted() => _event('profile_setup_completed');
  @override Future<void> logChallengeViewed(String challengeId) => _event('challenge_viewed', {'challenge_id': challengeId});
  @override Future<void> logChallengeStarted(String challengeId) => _event('challenge_started', {'challenge_id': challengeId});
  @override Future<void> logChallengeCompleted(String challengeId) => _event('challenge_completed', {'challenge_id': challengeId});
  @override Future<void> logStreakIncreased(int streak) => _event('streak_increased', {'streak': streak});
  @override Future<void> logAchievementUnlocked(String achievementId) => _event('achievement_unlocked', {'achievement_id': achievementId});
  @override Future<void> logLevelUp(int level) => _event('level_up', {'level': level});
  @override Future<void> logShareCardCreated() => _event('share_card_created');
  @override Future<void> logNotificationOpened() => _event('notification_opened');
}
