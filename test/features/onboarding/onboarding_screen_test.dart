import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  testWidgets('onboarding starts with the product promise and advances', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: OnboardingScreen())));
    expect(find.text('make today count.'), findsOneWidget);
    await tester.tap(find.text('continue'));
    await tester.pump();
    expect(find.text('one challenge. every day.'), findsOneWidget);
  });

  testWidgets('onboarding has accessible page semantics and final CTA', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: OnboardingScreen())));
    expect(find.bySemanticsLabel('onboarding page 1 of 3'), findsOneWidget);
    await tester.tap(find.text('continue'));
    await tester.pump();
    await tester.tap(find.text('continue'));
    await tester.pump();
    expect(find.text('get started'), findsOneWidget);
  });
}
