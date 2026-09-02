abstract interface class UserRepository {
  Future<void> createOrUpdateUser({required String uid, String? displayName, String? photoUrl});
  Future<Map<String, dynamic>?> getUser(String uid);
}

abstract interface class ChallengeRepository {
  Future<Map<String, dynamic>?> getDailyAssignment({required String uid, required String date});
  Future<void> assignDailyChallenge({required String uid, required String date, required String challengeId});
  Future<Map<String, dynamic>?> getChallenge(String challengeId);
}

abstract interface class ActivityRepository {
  Future<bool> isCompleted({required String uid, required String activityId});
  Future<void> recordCompletion({required String uid, required String activityId, required String challengeId, required String date, required int xpAwarded});
}
