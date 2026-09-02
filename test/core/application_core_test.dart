import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/database/repositories.dart';
import 'package:pulse/core/time/calendar_service.dart';
import 'package:pulse/features/achievements/application/achievement_service.dart';
import 'package:pulse/features/challenges/application/challenge_service.dart';
import 'package:pulse/features/challenges/application/complete_challenge.dart';
import 'package:pulse/features/challenges/data/challenge_seed_data.dart';
import 'package:pulse/models/challenge_model.dart';
import 'package:pulse/models/user_model.dart';
import 'package:pulse/services/streak_service.dart';
import 'package:pulse/services/xp_service.dart';

void main() {
  group('streak', () {
    final day = DateTime(2026, 9, 2);
    final calendar = CalendarService(now: () => day);
    test('first activity', () => expect(StreakService.calculateForCalendar(lastActivityDate: null, currentStreak: 0, longestStreak: 0, today: day, calendar: calendar).current, 1));
    test('same calendar day does not increase', () => expect(StreakService.calculateForCalendar(lastActivityDate: DateTime(2026, 9, 2, 23), currentStreak: 3, longestStreak: 3, today: day, calendar: calendar).current, 3));
    test('consecutive calendar day increases', () => expect(StreakService.calculateForCalendar(lastActivityDate: DateTime(2026, 9, 1, 23), currentStreak: 3, longestStreak: 3, today: day, calendar: calendar).current, 4));
    test('missed calendar day resets', () => expect(StreakService.calculateForCalendar(lastActivityDate: DateTime(2026, 8, 31, 23), currentStreak: 3, longestStreak: 3, today: day, calendar: calendar).current, 1));
    test('longest streak updates', () => expect(StreakService.calculateForCalendar(lastActivityDate: DateTime(2026, 9, 1), currentStreak: 5, longestStreak: 5, today: day, calendar: calendar).longest, 6));
  });

  group('xp', () {
    test('all difficulty rewards', () {
      expect(XPService.rewards['easy'], 10);
      expect(XPService.rewards['medium'], 25);
      expect(XPService.rewards['hard'], 50);
      expect(XPService.rewards['wild'], 75);
    });
    test('XP accumulation', () => expect(XPService.award(currentXP: 80, amount: 25).newXP, 105));
    test('level boundaries and level-up', () {
      expect(XPService.levelForXP(99), 1);
      expect(XPService.levelForXP(100), 2);
      expect(XPService.award(currentXP: 99, amount: 1).leveledUp, true);
    });
    test('progress calculation', () {
      expect(XPService.progress(0), 0);
      expect(XPService.progress(50), closeTo(.5, .0001));
      expect(XPService.progress(100), 0);
    });
  });

  group('achievements', () {
    const service = AchievementService();
    final when = DateTime(2026, 9, 2);
    test('first activity', () {
      final result = service.evaluate(totalActivities: 1, currentStreak: 1, completedCategories: {'health'}, unlockedAchievementIds: {}, unlockedAt: when);
      expect(result.newAchievements.map((e) => e.achievementId), contains('FIRST_STEP'));
    });
    test('3, 7, 14 and 30 day streaks', () {
      for (final pair in {'3': 'GETTING_STARTED', '7': 'WEEK_WARRIOR', '14': 'TWO_WEEKS', '30': 'UNSTOPPABLE'}.entries) {
        final result = service.evaluate(totalActivities: 2, currentStreak: int.parse(pair.key), completedCategories: {'health'}, unlockedAchievementIds: {}, unlockedAt: when);
        expect(result.newAchievements.map((e) => e.achievementId), contains(pair.value));
      }
    });
    test('100 activities', () {
      final result = service.evaluate(totalActivities: 100, currentStreak: 1, completedCategories: {'health'}, unlockedAchievementIds: {}, unlockedAt: when);
      expect(result.newAchievements.map((e) => e.achievementId), contains('CENTURY'));
    });
    test('five and all eight categories', () {
      final five = service.evaluate(totalActivities: 5, currentStreak: 1, completedCategories: {'random', 'social', 'health', 'money', 'learning'}, unlockedAchievementIds: {}, unlockedAt: when);
      expect(five.newAchievements.map((e) => e.achievementId), contains('EXPLORER'));
      final eight = service.evaluate(totalActivities: 8, currentStreak: 1, completedCategories: ChallengeCategory.values.map((e) => e.name).toSet(), unlockedAchievementIds: {}, unlockedAt: when);
      expect(eight.newAchievements.map((e) => e.achievementId), containsAll(['EXPLORER', 'MASTER_EXPLORER']));
    });
    test('duplicate unlock prevention', () {
      final result = service.evaluate(totalActivities: 100, currentStreak: 30, completedCategories: ChallengeCategory.values.map((e) => e.name).toSet(), unlockedAchievementIds: {'FIRST_STEP', 'GETTING_STARTED', 'WEEK_WARRIOR', 'TWO_WEEKS', 'UNSTOPPABLE', 'CENTURY', 'EXPLORER', 'MASTER_EXPLORER'}, unlockedAt: when);
      expect(result.newAchievements, isEmpty);
      expect(result.xpAwarded, 0);
    });
  });

  group('challenge assignment', () {
    final challenge = challengeSeedData.first;
    final repository = FakeChallengeRepository(challenge);
    final calendar = CalendarService(now: () => DateTime(2026, 9, 2, 23, 55));
    final service = ChallengeService(repository: repository, calendar: calendar);
    test('stable daily assignment and retry safety', () async {
      final first = await service.getOrAssignToday(uid: 'user-1');
      final second = await service.getOrAssignToday(uid: 'user-1');
      expect(first.challengeId, second.challengeId);
      expect(repository.assignmentWrites, 1);
    });
    test('retrieves the existing assignment', () async {
      expect((await service.getTodayAssignment(uid: 'user-1'))?.date, '2026-09-02');
      expect(repository.assignmentWrites, 1);
    });
  });

  group('completion', () {
    final challenge = challengeSeedData.first;
    final calendar = CalendarService(now: () => DateTime(2026, 9, 2, 12));
    test('successful completion', () async {
      final challengeRepo = FakeChallengeRepository(challenge);
      final completionRepo = FakeCompletionRepository(UserModel(uid: 'u1'), challenge);
      final useCase = CompleteChallenge(completionRepository: completionRepo, challengeRepository: challengeRepo, calendar: calendar);
      final result = await useCase.call(uid: 'u1');
      expect(result.completed, true);
      expect(result.xpAwarded, 35);
      expect(result.currentStreak, 1);
      expect(result.currentXP, 35);
      expect(result.newAchievements, contains('FIRST_STEP'));
      expect(result.events, isNotEmpty);
    });
    test('duplicate completion is idempotent', () async {
      final challengeRepo = FakeChallengeRepository(challenge);
      final completionRepo = FakeCompletionRepository(UserModel(uid: 'u2'), challenge);
      final useCase = CompleteChallenge(completionRepository: completionRepo, challengeRepository: challengeRepo, calendar: calendar);
      final first = await useCase.call(uid: 'u2');
      final second = await useCase.call(uid: 'u2');
      expect(first.completed, true);
      expect(second.completed, false);
      expect(second.alreadyCompleted, true);
      expect(completionRepo.user.totalActivities, 1);
    });
    test('failed transaction can safely retry', () async {
      final challengeRepo = FakeChallengeRepository(challenge);
      final completionRepo = FakeCompletionRepository(UserModel(uid: 'u3'), challenge)..failOnce = true;
      final useCase = CompleteChallenge(completionRepository: completionRepo, challengeRepository: challengeRepo, calendar: calendar);
      await expectLater(useCase.call(uid: 'u3'), throwsA(isA<StateError>()));
      expect((await useCase.call(uid: 'u3')).completed, true);
      expect(completionRepo.user.totalActivities, 1);
    });
  });
}

class FakeChallengeRepository implements ChallengeRepository {
  FakeChallengeRepository(this.challenge);
  final Challenge challenge;
  Map<String, dynamic>? assignment;
  int assignmentWrites = 0;
  @override Future<Map<String, dynamic>?> getChallenge(String challengeId) async => challenge.id == challengeId ? challenge.toMap() : null;
  @override Future<List<Challenge>> getActiveChallenges() async => [challenge];
  @override Future<Map<String, dynamic>?> getDailyAssignment({required String uid, required String date}) async => assignment;
  @override Future<void> assignDailyChallenge({required String uid, required String date, required String challengeId}) async { assignment ??= {'challengeId': challengeId, 'date': date, 'assignedAt': DateTime(2026, 9, 2), 'completed': false, 'completedAt': null}; assignmentWrites++; }
}

class FakeCompletionRepository implements CompletionRepository {
  FakeCompletionRepository(this.user, this.challenge);
  UserModel user;
  final Challenge challenge;
  bool activityExists = false;
  bool failOnce = false;
  @override Future<CompletionMutation> runAtomic({required String uid, required String activityId, required String date, required CompletionCalculator calculate}) async {
    if (failOnce) { failOnce = false; throw StateError('simulated transaction failure'); }
    final state = CompletionState(user: user, assignment: DailyChallengeAssignment(challengeId: challenge.id, date: date, assignedAt: DateTime(2026, 9, 2), completed: activityExists), challenge: challenge, activityExists: activityExists);
    final mutation = calculate(state);
    if (mutation.completed) { user = mutation.user; activityExists = true; }
    return mutation;
  }
}
