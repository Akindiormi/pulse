import '../../../core/backend/trusted_challenge_backend.dart';
import '../../../core/database/repositories.dart';
import '../../../models/challenge_model.dart';

class ChallengeService {
  const ChallengeService({required this.repository, required this.backend});

  final ChallengeRepository repository;
  final TrustedChallengeBackend backend;

  Future<Challenge?> getTodayChallenge({required String uid}) async {
    final assignment = await getTodayAssignment(uid: uid);
    final data = await repository.getChallenge(assignment.challengeId);
    return data == null ? null : Challenge.fromMap(assignment.challengeId, data);
  }

  Future<DailyChallengeAssignment> getTodayAssignment({required String uid}) async {
    final result = await backend.getOrAssignDailyChallenge();
    return DailyChallengeAssignment(
      challengeId: result.challengeId,
      date: result.date,
      assignedAt: result.assignedAt ?? DateTime.now(),
      completedAt: null,
      completed: result.completed,
    );
  }

  Future<DailyChallengeAssignment> getOrAssignToday({required String uid}) => getTodayAssignment(uid: uid);

  Future<Challenge> getOrAssignTodayChallenge({required String uid}) async {
    final assignment = await getOrAssignToday(uid: uid);
    final data = await repository.getChallenge(assignment.challengeId);
    if (data == null) throw StateError('Assigned challenge ${assignment.challengeId} does not exist.');
    final challenge = Challenge.fromMap(assignment.challengeId, data);
    if (!challenge.active) throw StateError('Assigned challenge ${assignment.challengeId} is inactive.');
    return challenge;
  }
}
