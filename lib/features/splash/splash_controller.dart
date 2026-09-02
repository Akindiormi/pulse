import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/providers.dart';
import '../../core/auth/auth_service.dart';

final splashControllerProvider = FutureProvider.autoDispose<String>((ref) async {
  final onboardingDone = (await SharedPreferencesAsync().getBool('pulse.onboarding_completed')) ?? false;
  if (!onboardingDone) return '/onboarding';
  final auth = ref.read(authServiceProvider);
  final state = await auth.authStateChanges.first;
  if (state.status == AuthStatus.unauthenticated) return '/auth';
  if (state.status == AuthStatus.authenticatedUnverified) return '/verify-email';
  if (state.uid == null) return '/auth';
  final user = await ref.read(userRepositoryProvider).getUserModel(state.uid!);
  if (user == null || (user.displayName ?? '').trim().isEmpty) return '/profile-setup';
  return '/home';
});
