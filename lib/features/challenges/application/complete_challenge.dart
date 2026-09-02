import '../../../core/database/repositories.dart';
import '../../../core/motion/pulse_events.dart';
import '../../../core/time/calendar_service.dart';
import '../../../models/activity_model.dart';
import '../../../services/streak_service.dart';
import '../../../services/xp_service.dart';
import '../../achievements/application/achievement_service.dart';

class CompletionResult {
  const CompletionResult({required this.completed, required this.alreadyCompleted, required this.xpAwarded, required this.previousXP, required this.currentXP, required this.previousStreak, required this.currentStreak, required this.longestStreak, required this.previousLevel, required this.newLevel, required this.leveledUp, required this.newAchievements, required this.events});
  final bool completed, alreadyCompleted, leveledUp;
  final int xpAwarded, previousXP, currentXP, previousStreak, currentStreak, longestStreak, previousLevel, newLevel;
  final List<String> newAchievements;
  final List<Object> events;
}

class CompleteChallenge {
  const CompleteChallenge({required this.completionRepository, required this.challengeRepository, this.calendar = const CalendarService(), this.achievementService = const AchievementService()});
  final CompletionRepository completionRepository;
  final ChallengeRepository challengeRepository;
  final CalendarService calendar;
  final AchievementService achievementService;

  Future<CompletionResult> call({required String uid, String? activityId}) async {
    final date = calendar.todayKey();
    final assignmentData = await challengeRepository.getDailyAssignment(uid: uid, date: date);
    if (assignmentData == null) throw StateError('No challenge is assigned for today.');
    final challengeId = assignmentData['challengeId'] as String?;
    if (challengeId == null || challengeId.isEmpty) throw StateError('Today\'s assignment is invalid.');
    final id = activityId ?? '$date-$challengeId';

    final mutation = await completionRepository.runAtomic(uid: uid, activityId: id, date: date, calculate: (state) {
      final user = state.user;
      if (state.activityExists || state.assignment?.completed == true) return CompletionMutation(completed: false, activity: null, user: user, newAchievements: const [], events: const []);
      final assignment = state.assignment;
      final challenge = state.challenge;
      if (assignment == null || challenge == null || assignment.challengeId != challengeId) throw StateError('Today\'s challenge assignment could not be verified.');
      if (!challenge.active) throw StateError('This challenge is no longer active.');
      final now = calendar.current();
      final streak = StreakService.calculateForCalendar(lastActivityDate: user.lastActivityDate, currentStreak: user.currentStreak, longestStreak: user.longestStreak, today: now, calendar: calendar);
      final nextCategories = {...user.completedCategories, challenge.category.name};
      final nextActivityCount = user.totalActivities + 1;
      final achievementEvaluation = achievementService.evaluate(totalActivities: nextActivityCount, currentStreak: streak.current, completedCategories: nextCategories, unlockedAchievementIds: user.unlockedAchievements, unlockedAt: now);
      final totalReward = challenge.xpReward + achievementEvaluation.xpAwarded;
      final xp = XPService.award(currentXP: user.xp, amount: totalReward);
      final unlockedIds = {...user.unlockedAchievements, ...achievementEvaluation.newAchievements.map((e) => e.achievementId)};
      final nextUser = user.copyWith(totalActivities: nextActivityCount, currentStreak: streak.current, longestStreak: streak.longest, xp: xp.newXP, level: xp.newLevel, lastActivityDate: now, completedCategories: nextCategories, unlockedAchievements: unlockedIds);
      final activity = ActivityModel(id: id, userId: uid, challengeId: challenge.id, date: date, xpAwarded: challenge.xpReward, completedAt: now, category: challenge.category.name);
      final events = <Object>[
        ActivityCompletedEvent(challengeId: challenge.id, xpAwarded: totalReward, newXP: xp.newXP, previousStreak: streak.previous, newStreak: streak.current, newAchievements: achievementEvaluation.newAchievements.map((e) => e.achievementId).toList(), leveledUp: xp.leveledUp),
        if (streak.changed && streak.current > streak.previous) StreakIncreasedEvent(previous: streak.previous, current: streak.current),
        ...achievementEvaluation.newAchievements.map((e) => AchievementUnlockedEvent(e.achievementId)),
        if (xp.leveledUp) LevelUpEvent(previousLevel: xp.previousLevel, newLevel: xp.newLevel),
      ];
      return CompletionMutation(completed: true, activity: activity, user: nextUser, newAchievements: achievementEvaluation.newAchievements, events: events);
    });

    final user = mutation.user;
    if (!mutation.completed) return CompletionResult(completed: false, alreadyCompleted: true, xpAwarded: 0, previousXP: user.xp, currentXP: user.xp, previousStreak: user.currentStreak, currentStreak: user.currentStreak, longestStreak: user.longestStreak, previousLevel: user.level, newLevel: user.level, leveledUp: false, newAchievements: const [], events: mutation.events);
    final completedEvent = mutation.events.whereType<ActivityCompletedEvent>().first;
    final levelEvents = mutation.events.whereType<LevelUpEvent>().toList(growable: false);
    final levelEvent = levelEvents.isEmpty ? null : levelEvents.first;
    return CompletionResult(completed: true, alreadyCompleted: false, xpAwarded: completedEvent.xpAwarded, previousXP: user.xp - completedEvent.xpAwarded, currentXP: user.xp, previousStreak: completedEvent.previousStreak, currentStreak: completedEvent.newStreak, longestStreak: user.longestStreak, previousLevel: levelEvent?.previousLevel ?? user.level, newLevel: user.level, leveledUp: completedEvent.leveledUp, newAchievements: completedEvent.newAchievements, events: mutation.events);
  }
}
