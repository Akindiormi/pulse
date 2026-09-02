import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/backend/trusted_challenge_backend.dart';
import 'package:pulse/core/database/repositories.dart';
import 'package:pulse/core/motion/pulse_events.dart';
import 'package:pulse/core/time/calendar_service.dart';
import 'package:pulse/features/achievements/application/achievement_service.dart';
import 'package:pulse/features/challenges/application/challenge_service.dart';
import 'package:pulse/features/challenges/application/complete_challenge.dart';
import 'package:pulse/features/challenges/data/challenge_seed_data.dart';
import 'package:pulse/models/challenge_model.dart';
import 'package:pulse/services/streak_service.dart';
import 'package:pulse/services/xp_service.dart';

final testDay = DateTime(2026, 9, 2);

void main() {
  final calendar = CalendarService(now: () => testDay);

  group('streak', () {
    test('first activity', () => expect(StreakService.calculateForCalendar(lastActivityDate: null, currentStreak: 0, longestStreak: 0, today: testDay, calendar: calendar).current, 1));
    test('same day', () => expect(StreakService.calculateForCalendar(lastActivityDate: DateTime(2026, 9, 2, 23), currentStreak: 3, longestStreak: 3, today: testDay, calendar: calendar).current, 3));
    test('consecutive day', () => expect(StreakService.calculateForCalendar(lastActivityDate: DateTime(2026, 9, 1, 23), currentStreak: 3, longestStreak: 3, today: testDay, calendar: calendar).current, 4));
    test('missed day and longest', () { final r = StreakService.calculateForCalendar(lastActivityDate: DateTime(2026, 8, 31), currentStreak: 3, longestStreak: 5, today: testDay, calendar: calendar); expect(r.current, 1); expect(r.longest, 5); });
  });

  group('XP', () {
    test('all difficulty rewards', () => expect(XPService.rewards, {'easy': 10, 'medium': 25, 'hard': 50, 'wild': 75}));
    test('accumulation and level boundaries', () { expect(XPService.award(currentXP: 80, amount: 25).newXP, 105); expect(XPService.levelForXP(99), 1); expect(XPService.levelForXP(100), 2); expect(XPService.award(currentXP: 99, amount: 1).leveledUp, true); });
    test('progress calculation', () { expect(XPService.progress(0), 0); expect(XPService.progress(50), closeTo(.5, .0001)); expect(XPService.progress(100), 0); });
  });

  group('achievements', () {
    const service = AchievementService();
    test('first, streak, century and categories', () {
      expect(service.evaluate(totalActivities: 1, currentStreak: 1, completedCategories: {'health'}, unlockedAchievementIds: {}, unlockedAt: testDay).newAchievements.map((e) => e.achievementId), contains('FIRST_STEP'));
      for (final p in {'3': 'GETTING_STARTED', '7': 'WEEK_WARRIOR', '14': 'TWO_WEEKS', '30': 'UNSTOPPABLE'}.entries) expect(service.evaluate(totalActivities: 2, currentStreak: int.parse(p.key), completedCategories: {'health'}, unlockedAchievementIds: {}, unlockedAt: testDay).newAchievements.map((e) => e.achievementId), contains(p.value));
      expect(service.evaluate(totalActivities: 100, currentStreak: 1, completedCategories: {'health'}, unlockedAchievementIds: {}, unlockedAt: testDay).newAchievements.map((e) => e.achievementId), contains('CENTURY'));
      final all = ChallengeCategory.values.map((e) => e.name).toSet();
      final result = service.evaluate(totalActivities: 8, currentStreak: 1, completedCategories: all, unlockedAchievementIds: {'EXPLORER'}, unlockedAt: testDay);
      expect(result.newAchievements.map((e) => e.achievementId), contains('MASTER_EXPLORER'));
      expect(result.newAchievements.map((e) => e.achievementId), isNot(contains('EXPLORER')));
    });
  });

  group('trusted completion integration', () {
    test('authoritative completion result becomes domain events without local reward calculation', () async {
      final backend = FakeTrustedBackend(completion: const CompleteChallengeResult(activityCompleted: true, alreadyCompleted: false, xpAwarded: 35, previousXP: 0, newXP: 35, previousStreak: 0, newStreak: 1, longestStreak: 1, previousLevel: 1, newLevel: 1, leveledUp: false, newAchievements: ['FIRST_STEP'], challengeId: 'challenge-1'));
      final result = await CompleteChallenge(backend: backend).call();
      expect(result.completed, true);
      expect(result.xpAwarded, 35);
      expect(result.currentXP, 35);
      expect(result.currentStreak, 1);
      expect(result.newAchievements, ['FIRST_STEP']);
      expect(result.events.whereType<AchievementUnlockedEvent>(), hasLength(1));
      expect(result.events.whereType<StreakIncreasedEvent>(), hasLength(1));
      expect(backend.receivedIdempotencyKey, isNull);
    });

    test('duplicate backend result does not locally award another reward', () async {
      final backend = FakeTrustedBackend(completion: const CompleteChallengeResult(activityCompleted: false, alreadyCompleted: true, xpAwarded: 0, previousXP: 35, newXP: 35, previousStreak: 1, newStreak: 1, longestStreak: 1, previousLevel: 1, newLevel: 1, leveledUp: false, newAchievements: [], challengeId: 'challenge-1'));
      final result = await CompleteChallenge(backend: backend).call();
      expect(result.completed, false);
      expect(result.alreadyCompleted, true);
      expect(result.xpAwarded, 0);
      expect(result.currentXP, 35);
      expect(result.events, isEmpty);
    });

    test('backend/network failure does not award locally and remains retryable', () async {
      final backend = FakeTrustedBackend(error: const TrustedBackendException(TrustedBackendErrorCode.unavailable, 'The service is temporarily unavailable.'));
      final useCase = CompleteChallenge(backend: backend);
      await expectLater(useCase.call(), throwsA(isA<TrustedBackendException>()));
      backend.error = null;
      backend.completion = const CompleteChallengeResult(activityCompleted: true, alreadyCompleted: false, xpAwarded: 10, previousXP: 0, newXP: 10, previousStreak: 0, newStreak: 1, longestStreak: 1, previousLevel: 1, newLevel: 1, leveledUp: false, newAchievements: [], challengeId: 'challenge-1');
      expect((await useCase.call()).currentXP, 10);
      expect(backend.calls, 2);
    });
  });

  group('daily challenge integration', () {
    test('daily challenge comes from backend and is parsed without client assignment', () async {
      final backend = FakeTrustedBackend(daily: DailyChallengeResult(date: '2026-09-02', challengeId: 'challenge-1', completed: false, assignedAt: testDay));
      final repository = FakeChallengeRepository(challengeSeedData.first);
      final service = ChallengeService(repository: repository, backend: backend);
      final assignment = await service.getOrAssignToday(uid: 'ignored-client-uid');
      expect(assignment.challengeId, 'challenge-1');
      expect(assignment.date, '2026-09-02');
      expect(repository.assignmentWrites, 0);
      expect(backend.dailyCalls, 1);
    });
  });
}

class FakeTrustedBackend implements TrustedChallengeBackend {
  FakeTrustedBackend({this.daily, this.completion, this.error});
  DailyChallengeResult? daily;
  CompleteChallengeResult? completion;
  TrustedBackendException? error;
  String? receivedIdempotencyKey;
  int calls = 0;
  int dailyCalls = 0;

  @override
  Future<DailyChallengeResult> getOrAssignDailyChallenge() async {
    dailyCalls++;
    return daily!;
  }

  @override
  Future<CompleteChallengeResult> completeChallenge({String? idempotencyKey}) async {
    calls++;
    receivedIdempotencyKey = idempotencyKey;
    if (error != null) throw error!;
    return completion!;
  }
}

class FakeChallengeRepository implements ChallengeRepository {
  FakeChallengeRepository(this.challenge);
  final Challenge challenge;
  int assignmentWrites = 0;

  @override
  Future<Map<String, dynamic>?> getChallenge(String id) async => id == challenge.id ? challenge.toMap() : null;

  @override
  Future<List<Challenge>> getActiveChallenges() async => [challenge];

  @override
  Future<Map<String, dynamic>?> getDailyAssignment({required String uid, required String date}) async => null;
}
