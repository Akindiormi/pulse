import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/core/theme/app_theme.dart';
import 'package:pulse/features/shell/presentation/pulse_shell.dart';

void main() {
  testWidgets('bottom navigation exposes four product destinations', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(Brightness.light, useGoogleFonts: false), home: const Scaffold(body: SizedBox(), bottomNavigationBar: PulseBottomNavigation(currentPath: '/home'))));
    expect(find.text('today'), findsOneWidget);
    expect(find.text('projects'), findsOneWidget);
    expect(find.text('progress'), findsOneWidget);
    expect(find.text('profile'), findsOneWidget);
  });
}
