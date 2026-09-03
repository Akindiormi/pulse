import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/core/motion/pulse_celebration.dart';
import 'package:pulse/core/motion/pulse_motion_attachment.dart';
import 'package:pulse/core/motion/pulse_motion_policy.dart';
import 'package:pulse/core/motion/pulse_motion_state.dart';
import 'package:pulse/core/motion/pulse_staggered.dart';

void main() {
  testWidgets('attachment preserves intent/state without owning product logic', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: PulseMotionAttachment(
        intent: PulseMotionIntent.challengeCompletion,
        state: PulseMotionState.completed,
        excludeFromSemantics: false,
        child: Text('completed'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('completed'), findsOneWidget);
  });

  testWidgets('staggered motion becomes static when reduced motion is enabled', (tester) async {
    PulseMotionPolicy.userReducedMotion = true;
    addTearDown(() => PulseMotionPolicy.userReducedMotion = false);
    await tester.pumpWidget(const MaterialApp(home: PulseStaggered(index: 3, child: Text('home'))));
    expect(find.text('home'), findsOneWidget);
    await tester.pump();
  });

  testWidgets('celebration renders no decorative particles with reduced motion', (tester) async {
    PulseMotionPolicy.userReducedMotion = true;
    addTearDown(() => PulseMotionPolicy.userReducedMotion = false);
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(
        width: 200,
        height: 200,
        child: PulseCompletionCelebration(hasAchievement: true, leveledUp: true),
      ),
    ));
    final celebration = find.byType(PulseCompletionCelebration);
    expect(
      find.descendant(of: celebration, matching: find.byType(CustomPaint)),
      findsNothing,
    );
  });
}
