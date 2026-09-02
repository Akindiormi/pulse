import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/di/providers.dart';

enum OnboardingMotionState { entering, active, exiting, skipped, completed }

class OnboardingController extends AsyncNotifier<bool> {
  static const _key = 'pulse.onboarding_completed';

  @override
  Future<bool> build() async => (await SharedPreferencesAsync().getBool(_key)) ?? false;

  Future<void> complete() async {
    await SharedPreferencesAsync().setBool(_key, true);
    state = const AsyncData(true);
    await ref.read(analyticsServiceProvider).logOnboardingCompleted();
  }

  Future<void> skip() async {
    await SharedPreferencesAsync().setBool(_key, true);
    state = const AsyncData(true);
    await ref.read(analyticsServiceProvider).logOnboardingSkipped();
  }
}

final onboardingControllerProvider = AsyncNotifierProvider<OnboardingController, bool>(OnboardingController.new);
