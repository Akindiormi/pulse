import '../../models/activity_model.dart';
import '../../models/achievement_model.dart';
import '../../models/challenge_model.dart';
import '../../models/user_model.dart';

abstract interface class UserRepository {
  Future<void> createOrUpdateUser({required String uid, String? displayName, String? photoUrl});
  Future<Map<String, dynamic>?> getUser(String uid);
  Future<UserModel?> getUserModel(String uid) async {
    final data = await getUser(uid);
    return data == null ? null : UserModel.fromMap(uid, data);
  }
  Future<void> updatePreferences({required String uid, required Map<String, dynamic> preferences}) async => throw UnimplementedError('User preferences are not implemented by this repository.');
}

abstract interface class ChallengeRepository {
  Future<Map<String, dynamic>?> getDailyAssignment({required String uid, required String date});
  Future<Map<String, dynamic>?> getChallenge(String challengeId);
  Future<List<Challenge>> getActiveChallenges() async => throw UnimplementedError('Active challenge listing is not implemented by this repository.');
}

abstract interface class ActivityRepository {
  Future<bool> isCompleted({required String uid, required String activityId});
  Future<List<ActivityModel>> getActivities(String uid) async => throw UnimplementedError('Activity listing is not implemented by this repository.');
  Future<Set<String>> getCompletedCategories(String uid) async => throw UnimplementedError('Category history is not implemented by this repository.');
}

abstract interface class AchievementRepository {
  Future<Set<String>> getUnlockedIds(String uid);
  Future<List<AchievementRecord>> getUnlockedRecords(String uid) async => throw UnimplementedError('Achievement record listing is not implemented by this repository.');
}
