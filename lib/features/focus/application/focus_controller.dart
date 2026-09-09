import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/database/focus_repository_errors.dart';
import '../../../core/database/repositories.dart';
import '../../../core/di/providers.dart';
import '../../../models/focus_session_model.dart';
import 'focus_session_state_machine.dart';

final focusControllerProvider =
    AsyncNotifierProvider<FocusController, FocusState>(FocusController.new);

enum FocusControllerStatus {
  idle,
  running,
  paused,
  completed,
  cancelled,
}

class FocusState {
  const FocusState({
    this.session,
    this.elapsedDuration = Duration.zero,
    this.isLoading = false,
    this.actionInProgress = false,
    this.error,
    this.recoveryComplete = false,
  });

  final FocusSession? session;
  final Duration elapsedDuration;
  final bool isLoading;
  final bool actionInProgress;
  final FocusRepositoryException? error;
  final bool recoveryComplete;

  FocusControllerStatus get status {
    final current = session;
    if (current == null) return FocusControllerStatus.idle;
    return switch (current.status) {
      FocusSessionStatus.running => FocusControllerStatus.running,
      FocusSessionStatus.paused => FocusControllerStatus.paused,
      FocusSessionStatus.completed => FocusControllerStatus.completed,
      FocusSessionStatus.cancelled => FocusControllerStatus.cancelled,
    };
  }

  bool get isActive => session?.status.isActive == true;

  FocusState copyWith({
    FocusSession? session,
    Duration? elapsedDuration,
    bool? isLoading,
    bool? actionInProgress,
    FocusRepositoryException? error,
    bool clearError = false,
    bool? recoveryComplete,
  }) {
    return FocusState(
      session: session ?? this.session,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
      isLoading: isLoading ?? this.isLoading,
      actionInProgress: actionInProgress ?? this.actionInProgress,
      error: clearError ? null : error ?? this.error,
      recoveryComplete: recoveryComplete ?? this.recoveryComplete,
    );
  }
}

class FocusController extends AsyncNotifier<FocusState>
    with WidgetsBindingObserver {
  Timer? _ticker;

  FocusRepository get _repository => ref.read(focusRepositoryProvider);

  @override
  Future<FocusState> build() async {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(_dispose);

    try {
      final authState = await ref.read(authServiceProvider).authStateChanges.first;
      if (authState.status != AuthStatus.authenticated || authState.uid == null) {
        return const FocusState(recoveryComplete: true);
      }

      final session = await _repository.getActiveSession();
      if (session == null) {
        return const FocusState(recoveryComplete: true);
      }

      final recovered = FocusState(
        session: session,
        elapsedDuration: _project(session),
        recoveryComplete: true,
      );
      _syncTicker(session);
      return recovered;
    } on FocusRepositoryException catch (error) {
      return FocusState(error: error, recoveryComplete: true);
    } catch (error) {
      return FocusState(
        error: FocusRepositoryException(
          FocusRepositoryErrorKind.database,
          'Focus recovery failed.',
          cause: error,
        ),
        recoveryComplete: true,
      );
    }
  }

  Future<void> start({
    FocusIntent? intent,
    String? taskId,
    int? plannedDurationSeconds,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.actionInProgress) return;
    if (current.isActive) {
      _setError(const FocusRepositoryException(
        FocusRepositoryErrorKind.invalidTransition,
        'A Focus session is already active.',
      ));
      return;
    }

    final duration = intent?.plannedDurationSeconds ?? plannedDurationSeconds;
    final resolvedTaskId = intent?.taskId ?? taskId;
    if (duration == null || duration <= 0) {
      _setError(const FocusRepositoryException(
        FocusRepositoryErrorKind.database,
        'Planned duration must be greater than zero.',
      ));
      return;
    }

    _beginAction(current);
    try {
      final session = await _repository.startSession(
        taskId: resolvedTaskId,
        plannedDurationSeconds: duration,
      );
      state = AsyncData(FocusState(
        session: session,
        elapsedDuration: _project(session),
        recoveryComplete: true,
      ));
      _syncTicker(session);
    } on FocusRepositoryException catch (error) {
      _finishWithError(current, error);
    } catch (error) {
      _finishWithError(current, FocusRepositoryException(
        FocusRepositoryErrorKind.database,
        'Unable to start Focus.',
        cause: error,
      ));
    }
  }

  Future<void> pause() => _transition(
        FocusSessionStatus.running,
        _repository.pauseSession,
        'Unable to pause Focus.',
      );

  Future<void> resume() => _transition(
        FocusSessionStatus.paused,
        _repository.resumeSession,
        'Unable to resume Focus.',
      );

  Future<void> complete() => _transition(
        null,
        _repository.completeSession,
        'Unable to complete Focus.',
        terminal: true,
      );

  Future<void> cancel() => _transition(
        null,
        _repository.cancelSession,
        'Unable to cancel Focus.',
        terminal: true,
      );

  Future<void> recover() async {
    if (state.valueOrNull?.actionInProgress == true) return;
    final previous = state.valueOrNull ?? const FocusState();
    state = AsyncData(previous.copyWith(isLoading: true, clearError: true));

    try {
      final session = await _repository.getActiveSession();
      if (session == null) {
        _stopTicker();
        state = const AsyncData(FocusState(recoveryComplete: true));
        return;
      }
      state = AsyncData(FocusState(
        session: session,
        elapsedDuration: _project(session),
        recoveryComplete: true,
      ));
      _syncTicker(session);
    } on FocusRepositoryException catch (error) {
      state = AsyncData(previous.copyWith(isLoading: false, error: error, recoveryComplete: true));
    } catch (error) {
      state = AsyncData(previous.copyWith(
        isLoading: false,
        error: FocusRepositoryException(
          FocusRepositoryErrorKind.database,
          'Focus recovery failed.',
          cause: error,
        ),
        recoveryComplete: true,
      ));
    }
  }

  void refreshProjection({DateTime? now}) {
    final current = state.valueOrNull;
    final session = current?.session;
    if (current == null || session == null || !session.isRunning) return;

    final projected = _project(session, now: now);
    if (projected == current.elapsedDuration) return;
    state = AsyncData(current.copyWith(elapsedDuration: projected));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      refreshProjection();
      final current = state.valueOrNull?.session;
      if (current?.isRunning == true) _startTicker();
    } else if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.detached) {
      _stopTicker();
    }
  }

  Future<void> _transition(
    FocusSessionStatus? requiredStatus,
    Future<FocusSession> Function(String sessionId) operation,
    String fallbackMessage, {
    bool terminal = false,
  }) async {
    final current = state.valueOrNull;
    final session = current?.session;
    if (current == null || session == null || current.actionInProgress) return;
    if (requiredStatus != null && session.status != requiredStatus) {
      _setError(const FocusRepositoryException(
        FocusRepositoryErrorKind.invalidTransition,
        'Focus is not in the required state for this action.',
      ));
      return;
    }
    if (requiredStatus == null && !session.status.isActive) {
      _setError(const FocusRepositoryException(
        FocusRepositoryErrorKind.invalidTransition,
        'Focus is not active.',
      ));
      return;
    }

    _beginAction(current);
    try {
      final updated = await operation(session.id);
      state = AsyncData(FocusState(
        session: updated,
        elapsedDuration: updated.isRunning
            ? _project(updated)
            : Duration(seconds: updated.activeDurationSeconds),
        recoveryComplete: true,
      ));
      _syncTicker(terminal ? null : updated);
    } on FocusRepositoryException catch (error) {
      _finishWithError(current, error);
    } catch (error) {
      _finishWithError(current, FocusRepositoryException(
        FocusRepositoryErrorKind.database,
        fallbackMessage,
        cause: error,
      ));
    }
  }

  Duration _project(FocusSession session, {DateTime? now}) {
    return Duration(
      seconds: FocusSessionStateMachine.projectedActiveDuration(
        session,
        now: now ?? DateTime.now(),
      ),
    );
  }

  void _beginAction(FocusState current) {
    state = AsyncData(current.copyWith(actionInProgress: true, clearError: true));
  }

  void _finishWithError(FocusState previous, FocusRepositoryException error) {
    state = AsyncData(previous.copyWith(actionInProgress: false, error: error));
  }

  void _setError(FocusRepositoryException error) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(error: error));
  }

  void _syncTicker(FocusSession? session) {
    if (session?.isRunning == true) {
      _startTicker();
    } else {
      _stopTicker();
    }
  }

  void _startTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => refreshProjection());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _dispose() {
    _stopTicker();
    WidgetsBinding.instance.removeObserver(this);
  }
}
