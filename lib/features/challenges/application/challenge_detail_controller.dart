import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/backend/trusted_challenge_backend.dart';
import '../../../core/di/providers.dart';
import '../../../core/motion/pulse_event_dispatcher.dart';
import '../../../core/motion/pulse_events.dart';
import '../../../core/motion/pulse_motion_state.dart';
import '../../../models/challenge_model.dart';
import 'complete_challenge.dart';

final challengeDetailControllerProvider = AsyncNotifierProvider.family<ChallengeDetailController, ChallengeDetailViewData, String>(ChallengeDetailController.new);

enum ChallengeDetailPhase {
  ready,
  starting,
  active,
  completing,
  completed,
  alreadyCompleted,
  unavailable,
  error,
}

class ChallengeDetailViewData {
  const ChallengeDetailViewData({required this.challenge, required this.phase, this.completion});

  final Challenge challenge;
  final ChallengeDetailPhase phase;
  final CompletionResult? completion;

  ChallengeDetailViewData copyWith({ChallengeDetailPhase? phase, CompletionResult? completion}) => ChallengeDetailViewData(
        challenge: challenge,
        phase: phase ?? this.phase,
        completion: completion ?? this.completion,
      );

  PulseMotionState get challengeMotionState => switch (phase) {
        ChallengeDetailPhase.ready => PulseMotionState.idle,
        ChallengeDetailPhase.starting => PulseMotionState.starting,
        ChallengeDetailPhase.active => PulseMotionState.idle,
        ChallengeDetailPhase.completing => PulseMotionState.completing,
        ChallengeDetailPhase.completed => PulseMotionState.completed,
        ChallengeDetailPhase.alreadyCompleted => PulseMotionState.alreadyCompleted,
        ChallengeDetailPhase.unavailable => PulseMotionState.unavailable,
        ChallengeDetailPhase.error => PulseMotionState.error,
      };

  PulseCompletionMotionState? get completionMotionState => switch (phase) {
        ChallengeDetailPhase.completing => PulseCompletionMotionState.pending,
        ChallengeDetailPhase.completed => PulseCompletionMotionState.success,
        ChallengeDetailPhase.alreadyCompleted => PulseCompletionMotionState.alreadyCompleted,
        ChallengeDetailPhase.error => PulseCompletionMotionState.error,
        _ => null,
      };

  PulseProgressMotionState get xpMotionState {
    final result = completion;
    if (result == null || !result.completed) return PulseProgressMotionState.unchanged;
    if (result.leveledUp) return PulseProgressMotionState.levelUp;
    if (result.xpAwarded > 0) return PulseProgressMotionState.xpGained;
    return PulseProgressMotionState.unchanged;
  }

  PulseStreakMotionState get streakMotionState {
    final result = completion;
    if (result == null || !result.completed) return PulseStreakMotionState.active;
    if (result.currentStreak > result.previousStreak) return PulseStreakMotionState.increased;
    return PulseStreakMotionState.maintained;
  }

  PulseAchievementMotionState get achievementMotionState => completion?.newAchievements.isNotEmpty == true
      ? PulseAchievementMotionState.newlyUnlocked
      : PulseAchievementMotionState.none;
}

class ChallengeDetailController extends FamilyAsyncNotifier<ChallengeDetailViewData, String> {
  late final String challengeId;

  @override
  Future<ChallengeDetailViewData> build(String arg) {
    challengeId = arg;
    return _load();
  }

  Future<ChallengeDetailViewData> _load() async {
    final authState = await ref.read(authServiceProvider).authStateChanges.first;
    if (authState.status != AuthStatus.authenticated || authState.uid == null) {
      throw const TrustedBackendException(TrustedBackendErrorCode.unauthenticated, 'Sign in to complete today’s Pulse.');
    }

    final assignment = await ref.read(challengeServiceProvider).getTodayAssignment(uid: authState.uid!);
    if (assignment.challengeId != challengeId) {
      throw const TrustedBackendException(TrustedBackendErrorCode.notFound, 'This challenge is not your active challenge today.');
    }

    final data = await ref.read(challengeRepositoryProvider).getChallenge(challengeId);
    if (data == null) {
      throw const TrustedBackendException(TrustedBackendErrorCode.notFound, 'Today’s challenge is unavailable right now.');
    }

    final challenge = Challenge.fromMap(challengeId, data);
    if (!challenge.active) {
      throw const TrustedBackendException(TrustedBackendErrorCode.notFound, 'Today’s challenge is unavailable right now.');
    }

    return ChallengeDetailViewData(
      challenge: challenge,
      phase: assignment.completed ? ChallengeDetailPhase.alreadyCompleted : ChallengeDetailPhase.ready,
    );
  }

  Future<void> start() async {
    final current = state.valueOrNull;
    if (current == null || current.phase != ChallengeDetailPhase.ready) return;
    state = AsyncData(current.copyWith(phase: ChallengeDetailPhase.starting));
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final latest = state.valueOrNull;
    if (latest?.phase == ChallengeDetailPhase.starting) {
      state = AsyncData(latest!.copyWith(phase: ChallengeDetailPhase.active));
    }
  }

  Future<void> complete() async {
    final current = state.valueOrNull;
    if (current == null || (current.phase != ChallengeDetailPhase.active && current.phase != ChallengeDetailPhase.ready)) return;

    state = AsyncData(current.copyWith(phase: ChallengeDetailPhase.completing));

    try {
      final result = await ref.read(completeChallengeProvider).call();
      if (result.alreadyCompleted) {
        state = AsyncData(current.copyWith(phase: ChallengeDetailPhase.alreadyCompleted, completion: result));
        return;
      }

      if (!result.completed) {
        state = AsyncData(current.copyWith(phase: ChallengeDetailPhase.error, completion: result));
        return;
      }

      state = AsyncData(current.copyWith(phase: ChallengeDetailPhase.completed, completion: result));
      final dispatcher = ref.read(pulseEventDispatcherProvider);
      unawaited(_dispatchEvents(dispatcher, result.events));
    } on TrustedBackendException catch (error) {
      if (error.code == TrustedBackendErrorCode.alreadyCompleted) {
        state = AsyncData(current.copyWith(phase: ChallengeDetailPhase.alreadyCompleted));
      } else {
        state = AsyncError(error, StackTrace.current);
      }
    } catch (_) {
      state = AsyncError(const TrustedBackendException(TrustedBackendErrorCode.internal, 'Something went wrong. Please try again.'), StackTrace.current);
    }
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> _dispatchEvents(PulseEventDispatcher dispatcher, List<Object> events) async {
    for (final event in events.whereType<PulseEvent>()) {
      await dispatcher.dispatch(event);
    }
  }
}
