import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse/features/profile/presentation/profile_setup_screen.dart';

void main() {
  testWidgets('profile setup exposes a single safe identity field', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: ProfileSetupScreen())));
    await tester.pump();
    expect(find.text('set up your Pulse profile'), findsOneWidget);
    expect(find.text('display name'), findsOneWidget);
    expect(find.text('continue'), findsOneWidget);
  });
}
