import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/di/providers.dart';
import '../../../core/auth/auth_service.dart';
import '../../onboarding/application/new_user_activation_controller.dart';

enum StartupDestination { onboarding, auth, home, profileSetup, firstFocus, firstWin }

class StartupController extends AsyncNotifier<StartupDestination> {
  static const onboardingKey = 'pulse.onboarding_completed';

  @override
  Future<StartupDestination> build() async {
    final prefs = SharedPreferencesAsync();
    final onboardingComplete = (await prefs.getBool(onboardingKey)) ?? false;
    if (!onboardingComplete) return StartupDestination.onboarding;

    final authState = await ref.read(authServiceProvider).authStateChanges.first;
    if (authState.status == AuthStatus.unauthenticated || authState.uid == null) return StartupDestination.auth;

    final profile = await ref.read(userRepositoryProvider).getUserModel(authState.uid!);
    if (profile == null || (profile.displayName?.trim().isEmpty ?? true)) return StartupDestination.profileSetup;

    final activation = await ref.read(newUserActivationProvider.future);
    if (activation.active) {
      return switch (activation.step) {
        ActivationStep.personal || ActivationStep.priority || ActivationStep.work => StartupDestination.profileSetup,
        ActivationStep.focus => StartupDestination.firstFocus,
        ActivationStep.firstWin => StartupDestination.firstWin,
        ActivationStep.complete => StartupDestination.home,
      };
    }
    return StartupDestination.home;
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

final startupControllerProvider = AsyncNotifierProvider<StartupController, StartupDestination>(StartupController.new);
