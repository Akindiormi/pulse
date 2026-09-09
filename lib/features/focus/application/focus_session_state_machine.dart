import '../../../models/focus_session_model.dart';

class FocusSessionStateMachine {
  const FocusSessionStateMachine._();

  static bool canTransition(
    FocusSessionStatus from,
    FocusSessionStatus to,
  ) {
    if (from == to) return true;

    return switch (from) {
      FocusSessionStatus.running => to == FocusSessionStatus.paused ||
          to == FocusSessionStatus.completed ||
          to == FocusSessionStatus.cancelled,
      FocusSessionStatus.paused => to == FocusSessionStatus.running ||
          to == FocusSessionStatus.completed ||
          to == FocusSessionStatus.cancelled,
      FocusSessionStatus.completed || FocusSessionStatus.cancelled => false,
    };
  }

  static FocusSession transition({
    required FocusSession session,
    required FocusSessionStatus to,
    required DateTime at,
    required int activeDurationSeconds,
  }) {
    if (!canTransition(session.status, to)) {
      throw StateError(
        'Invalid Focus transition: ${session.status.value} -> ${to.value}',
      );
    }
    if (activeDurationSeconds < session.activeDurationSeconds) {
      throw StateError('Focus active duration cannot decrease.');
    }
    if (at.isBefore(session.startedAt)) {
      throw StateError('Focus transition time cannot be before startedAt.');
    }

    final terminal = to == FocusSessionStatus.completed ||
        to == FocusSessionStatus.cancelled;

    return session.copyWith(
      status: to,
      activeDurationSeconds: activeDurationSeconds,
      endedAt: terminal ? at : null,
      updatedAt: at,
    );
  }

  static int projectedActiveDuration(
    FocusSession session, {
    required DateTime now,
  }) {
    if (!session.isRunning) return session.activeDurationSeconds;

    final lastPersistedAt = session.updatedAt ?? session.startedAt;
    final additionalSeconds = now.difference(lastPersistedAt).inSeconds;
    return session.activeDurationSeconds + additionalSeconds.clamp(0, 1 << 31);
  }

  static Duration projectedRemaining(
    FocusSession session, {
    required DateTime now,
  }) {
    final elapsed = projectedActiveDuration(session, now: now);
    return Duration(seconds: (session.plannedDurationSeconds - elapsed).clamp(0, 1 << 31));
  }
}
