import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse/core/auth/auth_service.dart';
import 'package:pulse/core/di/providers.dart';
import 'package:pulse/core/telemetry/analytics_service.dart';
import 'package:pulse/features/profile/presentation/profile_setup_screen.dart';

/// Test-only stand-in for [AnalyticsService]. ProfileSetupScreen fires an
/// analytics event from initState; without this override the real provider
/// would reach the live FirebaseAnalytics singleton, which isn't
/// initialized in a plain `flutter test` run.
class _FakeAnalyticsService implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// Test-only stand-in for [AuthService]. ProfileSetupScreen reads
/// `authStateChanges.first` from initState to prefill the display name;
/// without this override the real provider would reach the live
/// FirebaseAuth singleton, which isn't initialized in a plain
/// `flutter test` run. An unauthenticated state is enough here: the
/// screen's `_load()` returns early once `uid` is null, so no further
/// (e.g. Firestore-backed) providers are touched.
class _FakeAuthService implements AuthService {
  @override
  Stream<AuthState> get authStateChanges => Stream.value(const AuthState(status: AuthStatus.unauthenticated));

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  testWidgets('profile setup exposes a single safe identity field', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
        authServiceProvider.overrideWithValue(_FakeAuthService()),
      ],
      child: const MaterialApp(home: ProfileSetupScreen()),
    ));
    await tester.pump();
    expect(find.text('set up your Pulse profile'), findsOneWidget);
    expect(find.text('display name'), findsOneWidget);
    expect(find.text('continue'), findsOneWidget);
  });
}
