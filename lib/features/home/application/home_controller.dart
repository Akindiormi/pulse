import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/backend/trusted_challenge_backend.dart';
import '../../../core/di/providers.dart';
import '../../../models/challenge_model.dart';
import '../../../models/user_model.dart';
import '../../../services/xp_service.dart';

final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeViewData>(HomeController.new);

class HomeViewData {
  const HomeViewData({required this.user, required this.challenge, required this.completed, required this.nextLevelXP, required this.xpProgress});

  final UserModel user;
  final Challenge challenge;
  final bool completed;
  final int nextLevelXP;
  final double xpProgress;

  HomeViewData copyWith({UserModel? user, Challenge? challenge, bool? completed, int? nextLevelXP, double? xpProgress}) => HomeViewData(
        user: user ?? this.user,
        challenge: challenge ?? this.challenge,
        completed: completed ?? this.completed,
        nextLevelXP: nextLevelXP ?? this.nextLevelXP,
        xpProgress: xpProgress ?? this.xpProgress,
      );
}

class HomeController extends AsyncNotifier<HomeViewData> {
  @override
  Future<HomeViewData> build() => _load();

  Future<HomeViewData> _load() async {
    final authState = await ref.read(authServiceProvider).authStateChanges.first;
    if (authState.status != AuthStatus.authenticated || authState.uid == null) {
      throw const TrustedBackendException(TrustedBackendErrorCode.unauthenticated, 'Sign in to see your daily Pulse.');
    }

    final uid = authState.uid!;
    final userRepository = ref.read(userRepositoryProvider);
    final challengeService = ref.read(challengeServiceProvider);
    final challengeRepository = ref.read(challengeRepositoryProvider);

    final user = await userRepository.getUserModel(uid);
    if (user == null) throw const TrustedBackendException(TrustedBackendErrorCode.notFound, 'Your Pulse profile could not be found.');

    final assignment = await challengeService.getTodayAssignment(uid: uid);
    final data = await challengeRepository.getChallenge(assignment.challengeId);
    if (data == null) throw const TrustedBackendException(TrustedBackendErrorCode.notFound, 'Today’s challenge is unavailable right now.');
    final challenge = Challenge.fromMap(assignment.challengeId, data);
    if (!challenge.active) throw const TrustedBackendException(TrustedBackendErrorCode.notFound, 'Today’s challenge is unavailable right now.');

    return _viewData(user: user, challenge: challenge, completed: assignment.completed);
  }

  HomeViewData _viewData({required UserModel user, required Challenge challenge, required bool completed}) => HomeViewData(
        user: user,
        challenge: challenge,
        completed: completed,
        nextLevelXP: XPService.nextLevelXP(user.xp),
        xpProgress: XPService.progress(user.xp),
      );

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  void applyCompletion(CompleteChallengeResult result) {
    final current = state.valueOrNull;
    if (current == null) return;
    final user = current.user.copyWith(
      xp: result.newXP,
      currentStreak: result.newStreak,
      longestStreak: result.longestStreak,
      level: result.newLevel,
      totalActivities: result.activityCompleted ? current.user.totalActivities + 1 : current.user.totalActivities,
    );
    state = AsyncData(_viewData(user: user, challenge: current.challenge, completed: result.activityCompleted || result.alreadyCompleted));
  }
}
