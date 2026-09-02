import '../../../core/database/repositories.dart';
import '../../../core/time/calendar_service.dart';
import '../../../models/challenge_model.dart';

class ChallengeService {
  const ChallengeService({required this.repository, this.calendar = const CalendarService()});
  final ChallengeRepository repository;
  final CalendarService calendar;

  Future<Challenge?> getTodayChallenge({required String uid}) async {
    final assignment = await getTodayAssignment(uid: uid);
    if (assignment == null) return null;
    final data = await repository.getChallenge(assignment.challengeId);
    return data == null ? null : Challenge.fromMap(assignment.challengeId, data);
  }

  Future<DailyChallengeAssignment?> getTodayAssignment({required String uid}) async {
    final date = calendar.todayKey();
    final data = await repository.getDailyAssignment(uid: uid, date: date);
    return data == null ? null : DailyChallengeAssignment.fromMap(data, date: date);
  }

  Future<DailyChallengeAssignment> getOrAssignToday({required String uid}) async {
    final date = calendar.todayKey();
    final existing = await getTodayAssignment(uid: uid);
    if (existing != null) return existing;
    final active = await repository.getActiveChallenges();
    if (active.isEmpty) throw StateError('No active challenges are available.');
    final selected = active[_stableIndex('$uid:$date', active.length)];
    await repository.assignDailyChallenge(uid: uid, date: date, challengeId: selected.id);
    final persisted = await getTodayAssignment(uid: uid);
    if (persisted == null) throw StateError('Daily challenge assignment could not be persisted.');
    return persisted;
  }

  Future<Challenge> getOrAssignTodayChallenge({required String uid}) async {
    final assignment = await getOrAssignToday(uid: uid);
    final data = await repository.getChallenge(assignment.challengeId);
    if (data == null) throw StateError('Assigned challenge ${assignment.challengeId} does not exist.');
    final challenge = Challenge.fromMap(assignment.challengeId, data);
    if (!challenge.active) throw StateError('Assigned challenge ${assignment.challengeId} is inactive.');
    return challenge;
  }

  static int _stableIndex(String input, int length) {
    var hash = 7;
    for (final codeUnit in input.codeUnits) hash = (hash * 31 + codeUnit) & 0x7fffffff;
    return hash % length;
  }
}
