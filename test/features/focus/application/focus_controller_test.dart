import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pulse/core/auth/auth_service.dart';
import 'package:pulse/core/database/focus_repository_errors.dart';
import 'package:pulse/core/database/repositories.dart';
import 'package:pulse/features/focus/application/focus_controller.dart';
import 'package:pulse/models/focus_session_model.dart';

class FakeAuthService implements AuthService {
  @override
  Stream<AuthState> get authStateChanges => Stream.value(
        const AuthState(status: AuthStatus.authenticated, uid: 'user-1'),
      );

  @override
  Future<AuthState> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<AuthState> signInWithApple() => throw UnimplementedError();
  @override
  Future<AuthState> signInWithEmail({required String email, required String password}) => throw UnimplementedError();
  @override
  Future<AuthState> registerWithEmail({required String email, required String password}) => throw UnimplementedError();
  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();
  @override
  Future<bool> reloadVerificationState() => throw UnimplementedError();
  @override
  Future<void> sendPasswordResetEmail({required String email}) => throw UnimplementedError();
  @override
  Future<void> signOut() => throw UnimplementedError();
  @override
  Future<void> deleteAccount() => throw UnimplementedError();
}

class FakeFocusRepository implements FocusRepository {
  FakeFocusRepository({this.activeSession});

  FocusSession? activeSession;
  FocusRepositoryException? nextError;
  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int completeCalls = 0;
  int cancelCalls = 0;
  Completer<FocusSession>? startCompleter;

  final history = <FocusSession>[];

  @override
  Future<FocusSession> startSession({String? taskId, required int plannedDurationSeconds}) async {
    startCalls++;
    if (nextError != null) throw nextError!;
    if (startCompleter != null) return startCompleter!.future;
    final now = DateTime.utc(2026, 9, 10, 10);
    final session = FocusSession(
      id: 'session-new',
      userId: 'user-1',
      taskId: taskId,
      status: FocusSessionStatus.running,
      plannedDurationSeconds: plannedDurationSeconds,
      startedAt: now,
      activeDurationSeconds: 0,
      updatedAt: now,
    );
    activeSession = session;
    history.insert(0, session);
    return session;
  }

  @override
  Future<FocusSession?> getActiveSession() async {
    if (nextError != null) throw nextError!;
    return activeSession;
  }

  @override
  Future<FocusSession?> getSession(String sessionId) async =>
      history.where((session) => session.id == sessionId).firstOrNull;

  @override
  Future<List<FocusSession>> getSessionHistory({int limit = 100, int offset = 0}) async =>
      history.skip(offset).take(limit).toList();

  @override
  Future<List<FocusSession>> getSessionsForTask(String taskId, {int limit = 100, int offset = 0}) async =>
      history.where((session) => session.taskId == taskId).skip(offset).take(limit).toList();

  Future<FocusSession> _change(FocusSessionStatus status, int calls) async {
    if (nextError != null) throw nextError!;
    final current = activeSession!;
    final updated = current.copyWith(status: status, updatedAt: DateTime.utc(2026, 9, 10, 10, 30));
    activeSession = status.isActive ? updated : null;
    history.removeWhere((session) => session.id == updated.id);
    history.insert(0, updated);
    return updated;
  }

  @override
  Future<FocusSession> pauseSession(String sessionId) async {
    pauseCalls++;
    return _change(FocusSessionStatus.paused, pauseCalls);
  }

  @override
  Future<FocusSession> resumeSession(String sessionId) async {
    resumeCalls++;
    return _change(FocusSessionStatus.running, resumeCalls);
  }

  @override
  Future<FocusSession> completeSession(String sessionId) async {
    completeCalls++;
    return _change(FocusSessionStatus.completed, completeCalls);
  }

  @override
  Future<FocusSession> cancelSession(String sessionId) async {
    cancelCalls++;
    return _change(FocusSessionStatus.cancelled, cancelCalls);
  }
}

FocusSession runningSession({int activeSeconds = 1500}) {
  final updatedAt = DateTime.utc(2026, 9, 10, 10, 25);
  return FocusSession(
    id: 'session-1',
    userId: 'user-1',
    status: FocusSessionStatus.running,
    plannedDurationSeconds: 3600,
    startedAt: DateTime.utc(2026, 9, 10, 10),
    activeDurationSeconds: activeSeconds,
    updatedAt: updatedAt,
  );
}

ProviderContainer containerFor(FakeFocusRepository repository) => ProviderContainer(
      overrides: [
        focusRepositoryProvider.overrideWithValue(repository),
        authServiceProvider.overrideWithValue(FakeAuthService()),
      ],
    );

void main() {
  test('initialization with no active session reaches idle recovery state', () async {
    final repository = FakeFocusRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);

    final state = await container.read(focusControllerProvider.future);

    expect(state.status, FocusControllerStatus.idle);
    expect(state.recoveryComplete, isTrue);
    expect(state.session, isNull);
  });

  test('initialization recovers a running session and projects elapsed time', () async {
    final repository = FakeFocusRepository(activeSession: runningSession());
    final container = containerFor(repository);
    addTearDown(container.dispose);

    final state = await container.read(focusControllerProvider.future);

    expect(state.status, FocusControllerStatus.running);
    expect(state.elapsedDuration, const Duration(minutes: 25, seconds: 0));
    expect(state.recoveryComplete, isTrue);
  });

  test('paused recovery does not accumulate paused wall-clock time', () async {
    final session = runningSession().copyWith(status: FocusSessionStatus.paused);
    final repository = FakeFocusRepository(activeSession: session);
    final container = containerFor(repository);
    addTearDown(container.dispose);

    final state = await container.read(focusControllerProvider.future);

    expect(state.status, FocusControllerStatus.paused);
    expect(state.elapsedDuration, const Duration(minutes: 25));
  });

  test('start persists first, then exposes the running session', () async {
    final repository = FakeFocusRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(focusControllerProvider.notifier);
    await container.read(focusControllerProvider.future);

    await controller.start(plannedDurationSeconds: 1500);

    final state = container.read(focusControllerProvider).requireValue;
    expect(repository.startCalls, 1);
    expect(state.status, FocusControllerStatus.running);
    expect(state.actionInProgress, isFalse);
    expect(state.error, isNull);
  });

  test('pause failure keeps the last known running state and exposes error', () async {
    final repository = FakeFocusRepository(activeSession: runningSession());
    repository.nextError = const FocusRepositoryException(
      FocusRepositoryErrorKind.database,
      'network failed',
    );
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(focusControllerProvider.notifier);
    await container.read(focusControllerProvider.future);

    await controller.pause();

    final state = container.read(focusControllerProvider).requireValue;
    expect(state.status, FocusControllerStatus.running);
    expect(state.error?.message, 'network failed');
    expect(state.actionInProgress, isFalse);
  });

  test('pause, resume, complete and cancel stop or restart projection correctly', () async {
    final repository = FakeFocusRepository(activeSession: runningSession());
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(focusControllerProvider.notifier);
    await container.read(focusControllerProvider.future);

    await controller.pause();
    expect(container.read(focusControllerProvider).requireValue.status, FocusControllerStatus.paused);

    await controller.resume();
    expect(container.read(focusControllerProvider).requireValue.status, FocusControllerStatus.running);

    await controller.complete();
    expect(container.read(focusControllerProvider).requireValue.status, FocusControllerStatus.completed);

    await controller.cancel();
    expect(repository.cancelCalls, 0);
  });

  test('ticker projection never mutates persisted active duration', () async {
    final persisted = runningSession();
    final repository = FakeFocusRepository(activeSession: persisted);
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(focusControllerProvider.notifier);
    await container.read(focusControllerProvider.future);

    controller.refreshProjection(now: DateTime.utc(2026, 9, 10, 10, 35));

    final state = container.read(focusControllerProvider).requireValue;
    expect(state.elapsedDuration, const Duration(minutes: 35));
    expect(repository.activeSession!.activeDurationSeconds, 1500);
  });

  test('duplicate starts are guarded while the first request is in flight', () async {
    final repository = FakeFocusRepository()..startCompleter = Completer<FocusSession>();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    final controller = container.read(focusControllerProvider.notifier);
    await container.read(focusControllerProvider.future);

    final first = controller.start(plannedDurationSeconds: 1500);
    await Future<void>.delayed(Duration.zero);
    final second = controller.start(plannedDurationSeconds: 1500);

    expect(repository.startCalls, 1);
    repository.startCompleter!.complete(runningSession());
    await Future.wait([first, second]);
    expect(repository.startCalls, 1);
  });

  test('repository recovery failure is controlled rather than thrown as a UI error', () async {
    final repository = FakeFocusRepository()
      ..nextError = const FocusRepositoryException(
        FocusRepositoryErrorKind.database,
        'recovery failed',
      );
    final container = containerFor(repository);
    addTearDown(container.dispose);

    final state = await container.read(focusControllerProvider.future);

    expect(state.recoveryComplete, isTrue);
    expect(state.error?.message, 'recovery failed');
  });
}
