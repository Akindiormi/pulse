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

  group('challenge assignment', () {
    test('stable assignment, retrieval and no reassignment', () async {
      final repo = FakeChallengeRepository(challengeSeedData.first);
      final service = ChallengeService(repository: repo, calendar: calendar);
      final a = await service.getOrAssignToday(uid: 'u1');
      final b = await service.getOrAssignToday(uid: 'u1');
      expect(a.challengeId, b.challengeId);
      expect(repo.assignmentWrites, 1);
      expect((await service.getTodayAssignment(uid: 'u1'))?.date, '2026-09-02');
    });
  });

  group('completion', () {
    test('successful completion returns reward, streak, achievement and events', () async {
      final challenge = challengeSeedData.first;
      final challengeRepo = FakeChallengeRepository(challenge);
      await challengeRepo.assignDailyChallenge(uid: 'u1', date: '2026-09-02', challengeId: challenge.id);
      final repo = FakeCompletionRepository(UserModel(uid: 'u1'), challenge);
      final result = await CompleteChallenge(completionRepository: repo, challengeRepository: challengeRepo, calendar: calendar).call(uid: 'u1');
      expect(result.completed, true); expect(result.xpAwarded, 35); expect(result.currentStreak, 1); expect(result.currentXP, 35); expect(result.newAchievements, contains('FIRST_STEP')); expect(result.events, isNotEmpty);
    });
    test('duplicate completion is idempotent', () async {
      final challenge = challengeSeedData.first;
      final challengeRepo = FakeChallengeRepository(challenge);
      await challengeRepo.assignDailyChallenge(uid: 'u2', date: '2026-09-02', challengeId: challenge.id);
      final repo = FakeCompletionRepository(UserModel(uid: 'u2'), challenge);
      final useCase = CompleteChallenge(completionRepository: repo, challengeRepository: challengeRepo, calendar: calendar);
      await useCase.call(uid: 'u2');
      final second = await useCase.call(uid: 'u2');
      expect(second.completed, false); expect(second.alreadyCompleted, true); expect(repo.user.totalActivities, 1);
    });
  });
}

class FakeChallengeRepository implements ChallengeRepository {
  FakeChallengeRepository(this.challenge);
  final Challenge challenge;
  Map<String, dynamic>? assignment;
  int assignmentWrites = 0;
  @override Future<Map<String, dynamic>?> getChallenge(String id) async => id == challenge.id ? challenge.toMap() : null;
  @override Future<List<Challenge>> getActiveChallenges() async => [challenge];
  @override Future<Map<String, dynamic>?> getDailyAssignment({required String uid, required String date}) async => assignment;
  @override Future<void> assignDailyChallenge({required String uid, required String date, required String challengeId}) async { if (assignment == null) { assignment = {'challengeId': challengeId, 'date': date, 'assignedAt': testDay, 'completed': false, 'completedAt': null}; assignmentWrites++; } }
}

class FakeCompletionRepository implements CompletionRepository {
  FakeCompletionRepository(this.user, this.challenge);
  UserModel user;
  final Challenge challenge;
  bool activityExists = false;
  @override Future<CompletionMutation> runAtomic({required String uid, required String activityId, required String date, required CompletionCalculator calculate}) async {
    final state = CompletionState(user: user, assignment: DailyChallengeAssignment(challengeId: challenge.id, date: date, assignedAt: testDay, completed: activityExists), challenge: challenge, activityExists: activityExists);
    final mutation = calculate(state);
    if (mutation.completed) { user = mutation.user; activityExists = true; }
    return mutation;
  }
}
