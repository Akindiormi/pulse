import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/core/motion/pulse_motion_attachment.dart';
import 'package:pulse/core/motion/pulse_motion_policy.dart';
import 'package:pulse/core/motion/pulse_rive.dart';
import 'package:pulse/core/motion/pulse_motion_state.dart';

void main() {
  setUp(() => PulseMotionPolicy.userReducedMotion = false);
  tearDown(() => PulseMotionPolicy.userReducedMotion = false);

  testWidgets('missing Rive asset falls back to normal UI', (tester) async {
    const fallback = Text('fallback');
    await tester.pumpWidget(
      const MaterialApp(
        home: PulseRiveMotionHost(
          assetPath: '',
          intent: PulseMotionIntent.homeEntrance,
          state: PulseMotionState.entering,
          fallback: fallback,
        ),
      ),
    );

    expect(find.text('fallback'), findsOneWidget);
  });

  testWidgets('reduced motion bypasses Rive and preserves fallback', (tester) async {
    PulseMotionPolicy.userReducedMotion = true;
    const fallback = Text('reduced-motion fallback');
    await tester.pumpWidget(
      const MaterialApp(
        home: PulseRiveMotionHost(
          assetPath: 'assets/rive/missing.riv',
          intent: PulseMotionIntent.challengeCompletion,
          state: PulseCompletionMotionState.success,
          fallback: fallback,
        ),
      ),
    );

    expect(find.text('reduced-motion fallback'), findsOneWidget);
  });

  test('attachment payload keeps intent and reduced-motion metadata separate from artwork', () {
    const data = PulseMotionAttachmentData(
      intent: PulseMotionIntent.levelUp,
      state: PulseProgressMotionState.levelUp,
      reducedMotion: true,
      duration: Duration.zero,
    );

    expect(data.intent, PulseMotionIntent.levelUp);
    expect(data.state, PulseProgressMotionState.levelUp);
    expect(data.reducedMotion, isTrue);
    expect(data.duration, Duration.zero);
  });
}
