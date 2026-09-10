import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse/core/auth/auth_service.dart';
import 'package:pulse/core/di/providers.dart';
import 'package:pulse/core/telemetry/analytics_service.dart';
import 'package:pulse/features/profile/presentation/profile_setup_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeAnalyticsService implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakeAuthService implements AuthService {
  @override
  Stream<AuthState> get authStateChanges => Stream.value(const AuthState(status: AuthStatus.unauthenticated));

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
  });

  testWidgets('profile setup exposes the personal activation step', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
        authServiceProvider.overrideWithValue(_FakeAuthService()),
      ],
      child: const MaterialApp(home: ProfileSetupScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('make Pulse yours'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('What matters most to you right now?'), findsOneWidget);
    expect(find.text('continue'), findsOneWidget);
  });
}
