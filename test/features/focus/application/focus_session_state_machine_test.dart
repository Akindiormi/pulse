import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/focus/application/focus_session_state_machine.dart';
import 'package:pulse/models/focus_session_model.dart';

void main() {
  final startedAt = DateTime.utc(2026, 9, 9, 10, 0);
  final updatedAt = DateTime.utc(2026, 9, 9, 10, 25);

  FocusSession session({
    FocusSessionStatus status = FocusSessionStatus.running,
    int activeSeconds = 0,
    DateTime? updated,
  }) => FocusSession(
        id: 'session-1',
        userId: 'user-1',
        taskId: 'task-1',
        status: status,
        plannedDurationSeconds: 3600,
        startedAt: startedAt,
        activeDurationSeconds: activeSeconds,
        updatedAt: updated ?? startedAt,
      );

  group('transition rules', () {
    test('allows running to paused', () {
      expect(FocusSessionStateMachine.canTransition(FocusSessionStatus.running, FocusSessionStatus.paused), isTrue);
    });

    test('allows paused to running', () {
      expect(FocusSessionStateMachine.canTransition(FocusSessionStatus.paused, FocusSessionStatus.running), isTrue);
    });

    test('allows active states to complete or cancel', () {
      for (final status in [FocusSessionStatus.running, FocusSessionStatus.paused]) {
        expect(FocusSessionStateMachine.canTransition(status, FocusSessionStatus.completed), isTrue);
        expect(FocusSessionStateMachine.canTransition(status, FocusSessionStatus.cancelled), isTrue);
      }
    });

    test('rejects terminal lifecycle changes', () {
      for (final status in [FocusSessionStatus.completed, FocusSessionStatus.cancelled]) {
        expect(FocusSessionStateMachine.canTransition(status, FocusSessionStatus.running), isFalse);
        expect(FocusSessionStateMachine.canTransition(status, FocusSessionStatus.paused), isFalse);
      }
    });

    test('transition rejects decreasing active duration', () {
      expect(
        () => FocusSessionStateMachine.transition(
          session: session(activeSeconds: 1500, updated: updatedAt),
          to: FocusSessionStatus.paused,
          at: updatedAt,
          activeDurationSeconds: 1499,
        ),
        throwsStateError,
      );
    });

    test('completion persists terminal timestamp and accumulated duration', () {
      final completedAt = DateTime.utc(2026, 9, 9, 10, 30);
      final result = FocusSessionStateMachine.transition(
        session: session(activeSeconds: 1500, updated: updatedAt),
        to: FocusSessionStatus.completed,
        at: completedAt,
        activeDurationSeconds: 1800,
      );

      expect(result.status, FocusSessionStatus.completed);
      expect(result.activeDurationSeconds, 1800);
      expect(result.endedAt, completedAt);
      expect(result.updatedAt, completedAt);
    });
  });

  group('timer projection', () {
    test('running session projects elapsed active time from persisted state', () {
      final result = FocusSessionStateMachine.projectedActiveDuration(
        session(activeSeconds: 1500, updated: updatedAt),
        now: DateTime.utc(2026, 9, 9, 10, 35),
      );
      expect(result, 2100);
    });

    test('paused session does not accumulate wall-clock pause time', () {
      final result = FocusSessionStateMachine.projectedActiveDuration(
        session(status: FocusSessionStatus.paused, activeSeconds: 1500, updated: updatedAt),
        now: DateTime.utc(2026, 9, 9, 11, 0),
      );
      expect(result, 1500);
    });

    test('terminal session remains fixed', () {
      final endedAt = DateTime.utc(2026, 9, 9, 10, 30);
      final result = FocusSessionStateMachine.projectedActiveDuration(
        FocusSession(
          id: 'session-1',
          userId: 'user-1',
          taskId: 'task-1',
          status: FocusSessionStatus.completed,
          plannedDurationSeconds: 3600,
          startedAt: startedAt,
          endedAt: endedAt,
          activeDurationSeconds: 1800,
          updatedAt: endedAt,
        ),
        now: DateTime.utc(2026, 9, 9, 12, 0),
      );
      expect(result, 1800);
    });

    test('remaining time never becomes negative', () {
      final remaining = FocusSessionStateMachine.projectedRemaining(
        session(activeSeconds: 3590, updated: updatedAt),
        now: DateTime.utc(2026, 9, 9, 11, 0),
      );
      expect(remaining, Duration.zero);
    });
  });

  group('intent', () {
    test('supports standalone focus', () {
      const intent = FocusIntent(plannedDurationSeconds: 1500);
      expect(intent.isTaskBound, isFalse);
      expect(intent.isCalendarBound, isFalse);
    });

    test('supports task and calendar handoff metadata', () {
      const intent = FocusIntent(plannedDurationSeconds: 1800, taskId: 'task-1', calendarEventId: 'event-1');
      expect(intent.isTaskBound, isTrue);
      expect(intent.isCalendarBound, isTrue);
    });
  });
}
