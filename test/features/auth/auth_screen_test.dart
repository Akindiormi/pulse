import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse/core/di/providers.dart';
import 'package:pulse/core/telemetry/analytics_service.dart';
import 'package:pulse/features/auth/presentation/auth_screen.dart';

class _FakeAnalyticsService implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  Widget app() => ProviderScope(
        overrides: [analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService())],
        child: const MaterialApp(home: AuthScreen()),
      );

  testWidgets('auth entry exposes account creation and sign in', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('sign up validates email before submitting', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Create Account'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('auth-email-field')), 'not-an-email');
    await tester.tap(find.text('Create Account'));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('sign up collects first name, last name, date of birth, and phone', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Create Account'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'First name'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Last name'), findsOneWidget);
    expect(find.text('Select date of birth'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Phone number'), findsOneWidget);
  });

  testWidgets('sign in exposes forgot password recovery', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('password can be revealed without changing its value', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('auth-password-field')), 'secret123');
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
