import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/database/focus_repository_errors.dart';
import 'package:pulse/core/database/repositories.dart';
import 'package:pulse/models/focus_session_model.dart';

class FakeFocusRepository implements FocusRepository {
  final List<FocusSession> _sessions = <FocusSession>[];

  @override
  Future<FocusSession> startSession({String? taskId, required int plannedDurationSeconds}) async {
    if (_sessions.any((session) => session.status.isActive)) {
      throw const FocusRepositoryException(FocusRepositoryErrorKind.duplicateActiveSession, 'An active session already exists.');
    }
    final now = DateTime.utc(2026, 9, 10, 10);
    final session = FocusSession(id: 'session-${_sessions.length + 1}', userId: 'user-1', taskId: taskId, status: FocusSessionStatus.running, plannedDurationSeconds: plannedDurationSeconds, startedAt: now, activeDurationSeconds: 0, createdAt: now, updatedAt: now);
    _sessions.add(session);
    return session;
  }

  @override
  Future<FocusSession?> getActiveSession() async => _sessions.where((session) => session.status.isActive).firstOrNull;
  @override
  Future<FocusSession?> getSession(String sessionId) async => _sessions.where((session) => session.id == sessionId).firstOrNull;
  @override
  Future<List<FocusSession>> getSessionHistory({int limit = 100, int offset = 0}) async => List<FocusSession>.from(_sessions.reversed.skip(offset).take(limit));
  @override
  Future<List<FocusSession>> getSessionsForTask(String taskId, {int limit = 100, int offset = 0}) async => _sessions.where((session) => session.taskId == taskId).toList().reversed.skip(offset).take(limit).toList(growable: false);
  @override Future<FocusSession> pauseSession(String id) => _transition(id, FocusSessionStatus.paused);
  @override Future<FocusSession> resumeSession(String id) => _transition(id, FocusSessionStatus.running);
  @override Future<FocusSession> completeSession(String id) => _transition(id, FocusSessionStatus.completed);
  @override Future<FocusSession> cancelSession(String id) => _transition(id, FocusSessionStatus.cancelled);

  Future<FocusSession> _transition(String id, FocusSessionStatus next) async {
    final index = _sessions.indexWhere((session) => session.id == id);
    if (index < 0) throw const FocusRepositoryException(FocusRepositoryErrorKind.notFound, 'Focus session not found.');
    final current = _sessions[index];
    final allowed = current.status == FocusSessionStatus.running
        ? {FocusSessionStatus.paused, FocusSessionStatus.completed, FocusSessionStatus.cancelled}
        : current.status == FocusSessionStatus.paused
            ? {FocusSessionStatus.running, FocusSessionStatus.completed, FocusSessionStatus.cancelled}
            : <FocusSessionStatus>{};
    if (!allowed.contains(next)) throw const FocusRepositoryException(FocusRepositoryErrorKind.invalidTransition, 'Invalid transition.');
    final updated = current.copyWith(status: next, endedAt: next.isTerminal ? DateTime.utc(2026, 9, 10, 10, 30) : null);
    _sessions[index] = updated;
    return updated;
  }
}

void main() {
  test('standalone creation and active lookup', () async {
    final repository = FakeFocusRepository();
    final session = await repository.startSession(plannedDurationSeconds: 1800);
    expect(session.status, FocusSessionStatus.running);
    expect(session.taskId, isNull);
    expect(session.activeDurationSeconds, 0);
    expect((await repository.getActiveSession())?.id, session.id);
  });

  test('task-linked session is queryable by task', () async {
    final repository = FakeFocusRepository();
    final session = await repository.startSession(taskId: 'task-1', plannedDurationSeconds: 1500);
    expect((await repository.getSessionsForTask('task-1')).single.id, session.id);
    expect(await repository.getSessionsForTask('task-2'), isEmpty);
  });

  test('duplicate active session is rejected', () async {
    final repository = FakeFocusRepository();
    await repository.startSession(plannedDurationSeconds: 1200);
    expect(() => repository.startSession(plannedDurationSeconds: 1200), throwsA(isA<FocusRepositoryException>()));
  });

  test('pause and resume preserve the same session', () async {
    final repository = FakeFocusRepository();
    final session = await repository.startSession(plannedDurationSeconds: 1200);
    final paused = await repository.pauseSession(session.id);
    final resumed = await repository.resumeSession(session.id);
    expect(paused.status, FocusSessionStatus.paused);
    expect(resumed.status, FocusSessionStatus.running);
    expect(resumed.id, session.id);
    expect(resumed.activeDurationSeconds, 0);
  });

  test('completion remains readable as historical data', () async {
    final repository = FakeFocusRepository();
    final session = await repository.startSession(plannedDurationSeconds: 1200);
    final completed = await repository.completeSession(session.id);
    expect(completed.status, FocusSessionStatus.completed);
    expect(completed.endedAt, isNotNull);
    expect((await repository.getSession(session.id))?.status, FocusSessionStatus.completed);
    expect(await repository.getActiveSession(), isNull);
  });

  test('cancellation remains readable and is not active', () async {
    final repository = FakeFocusRepository();
    final session = await repository.startSession(plannedDurationSeconds: 1200);
    final cancelled = await repository.cancelSession(session.id);
    expect(cancelled.status, FocusSessionStatus.cancelled);
    expect(cancelled.endedAt, isNotNull);
    expect((await repository.getSession(session.id))?.status, FocusSessionStatus.cancelled);
    expect(await repository.getActiveSession(), isNull);
  });

  test('invalid terminal lifecycle transitions are rejected', () async {
    final repository = FakeFocusRepository();
    final session = await repository.startSession(plannedDurationSeconds: 1200);
    final completed = await repository.completeSession(session.id);
    expect(() => repository.resumeSession(completed.id), throwsA(isA<FocusRepositoryException>()));
    expect(() => repository.pauseSession(completed.id), throwsA(isA<FocusRepositoryException>()));
    expect(() => repository.cancelSession(completed.id), throwsA(isA<FocusRepositoryException>()));
  });

  test('history is newest first and includes terminal sessions', () async {
    final repository = FakeFocusRepository();
    final first = await repository.startSession(plannedDurationSeconds: 1200);
    await repository.completeSession(first.id);
    final second = await repository.startSession(plannedDurationSeconds: 900);
    await repository.cancelSession(second.id);
    final history = await repository.getSessionHistory();
    expect(history.map((session) => session.id), ['session-2', 'session-1']);
    expect(history.map((session) => session.status), [FocusSessionStatus.cancelled, FocusSessionStatus.completed]);
  });

  test('repository errors retain a meaningful category', () {
    const error = FocusRepositoryException(FocusRepositoryErrorKind.permissionDenied, 'Permission denied.');
    expect(error.kind, FocusRepositoryErrorKind.permissionDenied);
    expect(error.message, 'Permission denied.');
  });
}
