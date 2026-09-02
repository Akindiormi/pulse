import 'package:firebase_analytics/firebase_analytics.dart';
import 'analytics_service.dart';

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService(this.analytics);
  final FirebaseAnalytics analytics;

  Future<void> _event(String name, [Map<String, Object?> parameters = const {}]) => analytics.logEvent(name: name, parameters: parameters.map((key, value) => MapEntry(key, value is num || value is String ? value : value?.toString())));

  @override Future<void> logAppOpen() => _event('app_open');
  @override Future<void> logOnboardingCompleted() => _event('onboarding_completed');
  @override Future<void> logSignUp() => _event('sign_up');
  @override Future<void> logLogin() => _event('login');
  @override Future<void> logChallengeViewed(String challengeId) => _event('challenge_viewed', {'challenge_id': challengeId});
  @override Future<void> logChallengeStarted(String challengeId) => _event('challenge_started', {'challenge_id': challengeId});
  @override Future<void> logChallengeCompleted(String challengeId) => _event('challenge_completed', {'challenge_id': challengeId});
  @override Future<void> logStreakIncreased(int streak) => _event('streak_increased', {'streak': streak});
  @override Future<void> logAchievementUnlocked(String achievementId) => _event('achievement_unlocked', {'achievement_id': achievementId});
  @override Future<void> logLevelUp(int level) => _event('level_up', {'level': level});
  @override Future<void> logShareCardCreated() => _event('share_card_created');
  @override Future<void> logNotificationOpened() => _event('notification_opened');
}
