import '../../models/activity_model.dart';
import '../../models/challenge_model.dart';
import '../../models/user_model.dart';
import '../../models/achievement_model.dart';

abstract interface class UserRepository {
  Future<void> createOrUpdateUser({required String uid, String? displayName, String? photoUrl});
  Future<Map<String, dynamic>?> getUser(String uid);
  Future<UserModel?> getUserModel(String uid) async {
    final data = await getUser(uid);
    return data == null ? null : UserModel.fromMap(uid, data);
  }
}

abstract interface class ChallengeRepository {
  Future<Map<String, dynamic>?> getDailyAssignment({required String uid, required String date});
  Future<void> assignDailyChallenge({required String uid, required String date, required String challengeId});
  Future<Map<String, dynamic>?> getChallenge(String challengeId);
  Future<List<Challenge>> getActiveChallenges() async => throw UnimplementedError('Active challenge listing is not implemented by this repository.');
}

abstract interface class ActivityRepository {
  Future<bool> isCompleted({required String uid, required String activityId});
  Future<void> recordCompletion({required String uid, required String activityId, required String challengeId, required String date, required int xpAwarded});
  Future<List<ActivityModel>> getActivities(String uid) async => throw UnimplementedError('Activity listing is not implemented by this repository.');
  Future<Set<String>> getCompletedCategories(String uid) async => throw UnimplementedError('Category history is not implemented by this repository.');
}

abstract interface class AchievementRepository {
  Future<Set<String>> getUnlockedIds(String uid);
  Future<void> unlock({required String uid, required AchievementRecord record});
}

class CompletionState {
  const CompletionState({required this.user, required this.assignment, required this.challenge, required this.activityExists});
  final UserModel user;
  final DailyChallengeAssignment? assignment;
  final Challenge? challenge;
  final bool activityExists;
}

class CompletionMutation {
  const CompletionMutation({required this.completed, required this.activity, required this.user, required this.newAchievements, required this.events});
  final bool completed;
  final ActivityModel? activity;
  final UserModel user;
  final List<AchievementRecord> newAchievements;
  final List<Object> events;
}

typedef CompletionCalculator = CompletionMutation Function(CompletionState state);

abstract interface class CompletionRepository {
  Future<CompletionMutation> runAtomic({required String uid, required String activityId, required String date, required CompletionCalculator calculate});
}
