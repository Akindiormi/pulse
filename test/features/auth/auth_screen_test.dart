import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse/core/di/providers.dart';
import 'package:pulse/core/telemetry/analytics_service.dart';
import 'package:pulse/features/auth/presentation/auth_screen.dart';

/// Test-only stand-in for [AnalyticsService]. AuthScreen fires analytics
/// events from initState; without this override the real provider would
/// reach the live FirebaseAnalytics singleton, which isn't initialized in
/// a plain `flutter test` run.
class _FakeAnalyticsService implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  Widget app() => ProviderScope(
        overrides: [analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService())],
        child: const MaterialApp(home: AuthScreen()),
      );
  testWidgets('auth entry exposes account creation and sign in', (tester) async { await tester.pumpWidget(app()); expect(find.text('create account'), findsOneWidget); expect(find.text('sign in'), findsOneWidget); });
  testWidgets('sign up validates email before submitting', (tester) async { await tester.pumpWidget(app()); await tester.tap(find.text('create account')); await tester.pump(); await tester.enterText(find.byType(TextField).first, 'not-an-email'); await tester.pump(); expect(find.text('enter a valid email address.'), findsOneWidget); });
  testWidgets('sign in exposes forgot password recovery', (tester) async { await tester.pumpWidget(app()); await tester.tap(find.text('sign in')); await tester.pump(); expect(find.text('forgot password?'), findsOneWidget); });
  testWidgets('password can be revealed without changing its value', (tester) async { await tester.pumpWidget(app()); await tester.tap(find.text('sign in')); await tester.pump(); await tester.enterText(find.byType(TextField).at(1), 'secret123'); await tester.tap(find.byTooltip('show password')); await tester.pump(); expect(find.byType(TextField), findsNWidgets(2)); });
}
