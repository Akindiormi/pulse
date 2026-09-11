import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse/core/di/providers.dart';
import 'package:pulse/core/telemetry/analytics_service.dart';
import 'package:pulse/features/onboarding/presentation/onboarding_screen.dart';

class _FakeAnalyticsService implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Widget _app() => ProviderScope(
      overrides: [analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService())],
      child: const MaterialApp(home: OnboardingScreen()),
    );

void main() {
  testWidgets('onboarding starts with the product promise and advances', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('turn what’s in your head into a plan.'), findsOneWidget);
    await tester.tap(find.text('continue'));
    await tester.pump();
    expect(find.text('work on what matters now.'), findsOneWidget);
  });

  testWidgets('onboarding has accessible page semantics and final CTA', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.bySemanticsLabel('onboarding page 1 of 3'), findsOneWidget);
    await tester.tap(find.text('continue'));
    await tester.pump();
    await tester.tap(find.text('continue'));
    await tester.pump();
    expect(find.text('get started'), findsOneWidget);
  });
}
