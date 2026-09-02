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
  final day = DateTime(2026, 9, 2);
  final calendar = CalendarService(now: () => day);

  group('streak', () {
    test('first activity starts at one', () => expect(StreakService.calculateForCalendar(lastActivityDate: null, currentStreak: 0, longestStreak: 0, today: day, calendar: calendar).current, 1));
    test('same day does not increase', () => expect(StreakService.calculateForCalendar(lastActivityDate: DateTime(2026, 9, 2, 23), currentStreak: 3, longestStreak: 3, today: day, calendar: calendar).current, 3));
    test('consecutive day increases', () => expect(StreakService.calculateForCalendar(lastActivityDate: DateTime(2026, 9, 1, 23), currentStreak: 3, longestStreak: 3, today: day, calendar: calendar).current, 4));
    test('missed day resets and longest is retained', () {
      final result = StreakService.calculateForCalendar(lastActivityDate: DateTime(2026, 8, 31), currentStreak: 3, longestStreak: 5, today: day, calendar: calendar);
      expect(result.current, 1);
      expect(result.longest, 5);
    });
  });

  group('XP', () {
    test('all difficulty rewards', () {
      expect(XPService.rewards, {'easy': 10, 'medium': 25, 'hard': 50, 'wild': 75});
    });
    test('accumulation and level boundary', () {
      expect(XPService.award(currentXP: 80, amount: 25).newXP, 105);
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
    test('first activity, streak milestones and 100 activities', () {
      expect(service.evaluate(totalActivities: 1, currentStreak: 1, completedCategories: {'health'}, unlockedAchievementIds: {}, unlockedAt: day).newAchievements.map((e) => e.achievementId), contains('FIRST_STEP'));
      for (final pair in {'3': 'GETTING_STARTED', '7': 'WEEK_WARRIOR', '14': 'TWO_WEEKS', '30': 'UNSTOPPABLE'}.entries) {
        expect(service.evaluate(totalActivities: 2, currentStreak: int.parse(pair.key), completedCategories: {'health'}, unlockedAchievementIds: {}, unlockedAt: day).newAchievements.map((e) => e.achievementId), contains(pair.value));
      }
      expect(service.evaluate(totalActivities: 100, currentStreak: 1, completedCategories: {'health'}, unlockedAchievementIds: {}, unlockedAt: day).newAchievements.map((e) => e.achievementId), contains('CENTURY'));
    });
    test('category achievements and duplicate prevention', () {
      final categories = {'random', 'social', 'health', 'money', 'learning'};
      expect(service.evaluate(totalActivities: 5, currentStreak: 1, completedCategories: categories, unlockedAchievementIds: {}, unlockedAt: day).newAchievements.map((e) => e.achievementId), contains('EXPLORER'));
      final all = ChallengeCategory.values.map((e) => e.name).toSet();
      final result = service.evaluate(totalActivities: 8, currentStreak: 1, completedCategories: all, unlockedAchievementIds: {'EXPLORER'}, unlockedAt: day);
      expect(result.newAchievements.map((e) => e.achievementId), contains('MASTER_EXPLORER'));
      expect(result.newAchievements.map((e) => e.achievementId), isNot(contains('EXPLORER')));
    });
  });

  group('challenge assignment', () {
    test('stable assignment and retrieval', () async {
      final repository = FakeChallengeRepository(challengeSeedData.first);
      final service = ChallengeService(repository: repository, calendar: calendar);
      final first = await service.getOrAssignToday(uid: 'user-1');
      final second = await service.getOrAssignToday(uid: 'user-1');
      expect(first.challengeId, second.challengeId);
      expect(repository.assignmentWrites, 1);
      expect((await service.getTodayAssignment(uid: 'user-1'))?.date, '2026-09-02');
    });
  });

  group('completion', () {
    test('successful completion calculates reward, streak, achievement and events', () async {
      final challenge = challengeSeedData.first;
      final challengeRepo = FakeChallengeRepository(challenge);
      await challengeRepo.assignDailyChallenge(uid: 'u1', date: '2026-09-02', challengeId: challenge.id);
      final completionRepo = FakeCompletionRepository(UserModel(uid: 'u1'), challenge);
      final result = await CompleteChallenge(completionRepository: completionRepo, challengeRepository: challengeRepo, calendar: calendar).call(uid: 'u1');
      expect(result.completed, true);
      expect(result.xpAwarded, 35);
      expect(result.currentStreak, 1);
      expect(result.currentXP, 35);
      expect(result.newAchievements, contains('FIRST_STEP'));
      expect(result.events, isNotEmpty);
    });
    test('duplicate completion is idempotent', () async {
      final challenge = challengeSeedData.first;
      final challengeRepo = FakeChallengeRepository(challenge);
      await challengeRepo.assignDailyChallenge(uid: 'u2', date: '2026-09-02', challengeId: challenge.id);
      final completionRepo = FakeCompletionRepository(UserModel(uid: 'u2'), challenge);
      final useCase = CompleteChallenge(completionRepository: completionRepo, challengeRepository: challengeRepo, calendar: calendar);
      expect((await useCase.call(uid: 'u2')).completed, true);
      final second = await useCase.call(uid: 'u2');
      expect(second.completed, false);
      expect(second.alreadyCompleted, true);
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
  @override Future<void> assignDailyChallenge({required String uid, required String date, required String challengeId}) async { assignment ??= {'challengeId': challengeId, 'date': date, 'assignedAt': day, 'completed': false, 'completedAt': null}; assignmentWrites++; }
}

class FakeCompletionRepository implements CompletionRepository {
  FakeCompletionRepository(this.user, this.challenge);
  UserModel user;
  final Challenge challenge;
  bool activityExists = false;
  @override Future<CompletionMutation> runAtomic({required String uid, required String activityId, required String date, required CompletionCalculator calculate}) async {
    final state = CompletionState(user: user, assignment: DailyChallengeAssignment(challengeId: challenge.id, date: date, assignedAt: day, completed: activityExists), challenge: challenge, activityExists: activityExists);
    final mutation = calculate(state);
    if (mutation.completed) { user = mutation.user; activityExists = true; }
    return mutation;
  }
}
