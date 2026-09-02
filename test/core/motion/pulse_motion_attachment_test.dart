import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/motion/pulse_motion_attachment.dart';
import 'package:pulse/core/motion/pulse_motion_policy.dart';
import 'package:pulse/core/motion/pulse_motion_state.dart';

void main() {
  setUp(() => PulseMotionPolicy.userReducedMotion = false);
  tearDown(() => PulseMotionPolicy.userReducedMotion = false);

  test('motion attachment carries product intent and state without animation knowledge', () {
    const data = PulseMotionAttachmentData(
      intent: PulseMotionIntent.challengeCompletion,
      state: PulseCompletionMotionState.success,
      reducedMotion: false,
      duration: Duration(milliseconds: 220),
    );

    expect(data.intent, PulseMotionIntent.challengeCompletion);
    expect(data.state, PulseCompletionMotionState.success);
    expect(data.reducedMotion, isFalse);
  });

  testWidgets('reduced motion suppresses attachment overlays', (tester) async {
    PulseMotionPolicy.userReducedMotion = true;
    var built = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PulseMotionBoundaryV2(
          intent: PulseMotionIntent.levelUp,
          state: PulseProgressMotionState.levelUp,
          child: const SizedBox(width: 20, height: 20),
          overlayBuilder: (_, __) {
            built = true;
            return const ColoredBox(color: Colors.red);
          },
        ),
      ),
    );

    expect(built, isTrue);
    expect(find.byType(ColoredBox), findsNothing);
  });

  testWidgets('motion policy returns zero duration for reduced motion', (tester) async {
    PulseMotionPolicy.userReducedMotion = true;
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    expect(PulseMotionPolicy.duration(context, const Duration(seconds: 1)), Duration.zero);
    expect(PulseMotionPolicy.microDuration(context), Duration.zero);
  });
}
