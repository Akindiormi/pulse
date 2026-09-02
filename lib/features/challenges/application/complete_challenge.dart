import '../../../core/backend/trusted_challenge_backend.dart';
import '../../../core/motion/pulse_events.dart';

class CompletionResult {
  const CompletionResult({required this.completed, required this.alreadyCompleted, required this.xpAwarded, required this.previousXP, required this.currentXP, required this.previousStreak, required this.currentStreak, required this.longestStreak, required this.previousLevel, required this.newLevel, required this.leveledUp, required this.newAchievements, required this.events, this.challengeId});

  final bool completed, alreadyCompleted, leveledUp;
  final int xpAwarded, previousXP, currentXP, previousStreak, currentStreak, longestStreak, previousLevel, newLevel;
  final List<String> newAchievements;
  final List<Object> events;
  final String? challengeId;
}

class CompleteChallenge {
  const CompleteChallenge({required this.backend});

  final TrustedChallengeBackend backend;

  Future<CompletionResult> call({String? idempotencyKey}) async {
    final result = await backend.completeChallenge(idempotencyKey: idempotencyKey);
    if (!result.activityCompleted) {
      return CompletionResult(
        completed: false,
        alreadyCompleted: result.alreadyCompleted,
        xpAwarded: 0,
        previousXP: result.previousXP,
        currentXP: result.newXP,
        previousStreak: result.previousStreak,
        currentStreak: result.newStreak,
        longestStreak: result.longestStreak,
        previousLevel: result.previousLevel,
        newLevel: result.newLevel,
        leveledUp: false,
        newAchievements: const [],
        events: const [],
        challengeId: result.challengeId,
      );
    }

    final events = <Object>[
      if (result.challengeId != null)
        ActivityCompletedEvent(
          challengeId: result.challengeId!,
          xpAwarded: result.xpAwarded,
          newXP: result.newXP,
          previousStreak: result.previousStreak,
          newStreak: result.newStreak,
          newAchievements: result.newAchievements,
          leveledUp: result.leveledUp,
        ),
      if (result.newStreak > result.previousStreak) StreakIncreasedEvent(previous: result.previousStreak, current: result.newStreak),
      ...result.newAchievements.map(AchievementUnlockedEvent.new),
      if (result.leveledUp) LevelUpEvent(previousLevel: result.previousLevel, newLevel: result.newLevel),
    ];

    return CompletionResult(
      completed: true,
      alreadyCompleted: false,
      xpAwarded: result.xpAwarded,
      previousXP: result.previousXP,
      currentXP: result.newXP,
      previousStreak: result.previousStreak,
      currentStreak: result.newStreak,
      longestStreak: result.longestStreak,
      previousLevel: result.previousLevel,
      newLevel: result.newLevel,
      leveledUp: result.leveledUp,
      newAchievements: result.newAchievements,
      events: events,
      challengeId: result.challengeId,
    );
  }
}
