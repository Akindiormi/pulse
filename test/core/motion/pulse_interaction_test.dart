import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/motion/pulse_motion_policy.dart';
import 'package:pulse/core/widgets/pulse_interaction.dart';

void main() {
  setUp(() => PulseMotionPolicy.userReducedMotion = false);
  tearDown(() => PulseMotionPolicy.userReducedMotion = false);

  testWidgets('press interaction remains at rest with reduced motion', (tester) async {
    PulseMotionPolicy.userReducedMotion = true;
    await tester.pumpWidget(
      const MaterialApp(
        home: PulsePressScale(child: SizedBox(width: 48, height: 48)),
      ),
    );

    expect(find.byType(PulsePressScale), findsOneWidget);
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1);
  });

  testWidgets('press interaction is lifecycle-safe after pointer cancel', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PulsePressScale(child: SizedBox(width: 48, height: 48)),
      ),
    );

    final target = find.byType(SizedBox);
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1);
  });
}
