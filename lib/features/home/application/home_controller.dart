import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/backend/trusted_challenge_backend.dart';
import '../../../core/database/repositories.dart';
import '../../../core/di/providers.dart';
import '../../../models/challenge_model.dart';
import '../../../models/user_model.dart';

final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeViewData>(HomeController.new);

class HomeViewData {
  const HomeViewData({required this.user, required this.challenge, required this.completed});

  final UserModel user;
  final Challenge challenge;
  final bool completed;

  HomeViewData copyWith({UserModel? user, Challenge? challenge, bool? completed}) => HomeViewData(
        user: user ?? this.user,
        challenge: challenge ?? this.challenge,
        completed: completed ?? this.completed,
      );
}

class HomeController extends AsyncNotifier<HomeViewData> {
  @override
  Future<HomeViewData> build() async {
    final auth = ref.read(authServiceProvider);
    final authState = await auth.authStateChanges.first;
    if (authState.status != AuthStatus.authenticated || authState.uid == null) {
      throw const TrustedBackendException(TrustedBackendErrorCode.unauthenticated, 'Sign in to see your daily Pulse.');
    }

    final uid = authState.uid!;
    final userRepository = ref.read(userRepositoryProvider);
    final challengeService = ref.read(challengeServiceProvider);

    final user = await userRepository.getUserModel(uid);
    if (user == null) throw const TrustedBackendException(TrustedBackendErrorCode.notFound, 'Your Pulse profile could not be found.');

    final assignment = await challengeService.getTodayAssignment(uid: uid);
    final challenge = await challengeService.getTodayChallenge(uid: uid);
    if (challenge == null) throw const TrustedBackendException(TrustedBackendErrorCode.notFound, 'Today’s challenge is unavailable right now.');

    return HomeViewData(user: user, challenge: challenge, completed: assignment.completed);
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  void applyCompletion(CompleteChallengeResult result) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        user: current.user.copyWith(
          xp: result.newXP,
          currentStreak: result.newStreak,
          longestStreak: result.longestStreak,
          level: result.newLevel,
          totalActivities: result.activityCompleted ? current.user.totalActivities + 1 : current.user.totalActivities,
        ),
        completed: result.activityCompleted || result.alreadyCompleted,
      ),
    );
  }
}
