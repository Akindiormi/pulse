import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/design/pulse_tokens.dart';
import '../../lib/core/theme/app_theme.dart';
import '../../lib/core/motion/pulse_motion_state.dart';
import '../../lib/core/widgets/pulse_achievement_badge.dart';
import '../../lib/core/widgets/pulse_button.dart';
import '../../lib/core/widgets/pulse_progress.dart';
import '../../lib/core/widgets/pulse_states.dart';
import '../../lib/core/widgets/pulse_streak.dart';
import '../../lib/features/shell/presentation/pulse_shell.dart';
import '../../lib/models/achievement_model.dart';
import '../../lib/models/challenge_model.dart';

void main() {
  test('Pulse theme keeps the product color contract', () {
    expect(buildAppTheme(Brightness.light).scaffoldBackgroundColor, PulseColors.lightBackground);
    expect(buildAppTheme(Brightness.dark).scaffoldBackgroundColor, PulseColors.darkBackground);
    expect(PulseColors.accent, const Color(0xFFFF6B4A));
  });

  test('motion states expose the product interaction vocabulary', () {
    expect(PulseMotionState.values, containsAll([PulseMotionState.pressed, PulseMotionState.completing, PulseMotionState.completed, PulseMotionState.error]));
    expect(PulseProgressMotionState.values, contains(PulseProgressMotionState.levelUp));
    expect(PulseStreakMotionState.values, contains(PulseStreakMotionState.milestone));
  });

  testWidgets('reusable foundation components render supplied states', (tester) async {
    final definition = AchievementDefinition(id: 'first', name: 'First Pulse', description: 'Complete one challenge.', type: AchievementType.activityCount, threshold: 1, xpReward: 20, iconAsset: 'first');
    final challenge = Challenge(id: 'c1', title: 'Take a different route home', description: 'Change one small thing today.', category: ChallengeCategory.random, difficulty: Difficulty.easy, xpReward: 20, estimatedMinutes: 10, active: true);

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: Column(children: [
        PulseButton(label: 'continue', onPressed: () {}),
        PulseXpProgress(currentXp: 30, nextLevelXp: 100, level: 2),
        const PulseStreak(current: 4, longest: 9, state: PulseStreakMotionState.increased),
        PulseAchievementBadge(definition: definition, newlyUnlocked: true, progress: 1),
        const PulseOfflineState(),
        const PulseEmptyState(title: 'nothing here', message: 'come back soon.'),
        const PulseErrorState(message: 'something went wrong.'),
        Text(challenge.title),
      ])),
    ));

    expect(find.text('continue'), findsOneWidget);
    expect(find.text('30 / 100 XP'), findsOneWidget);
    expect(find.text('4 days'), findsOneWidget);
    expect(find.text('First Pulse'), findsOneWidget);
    expect(find.text('you\'re offline. pulse will retry when you\'re connected.'), findsOneWidget);
    expect(find.text('nothing here'), findsOneWidget);
    expect(find.text('something went wrong.'), findsOneWidget);
    expect(find.text(challenge.title), findsOneWidget);
  });

  testWidgets('bottom navigation exposes four product destinations', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildAppTheme(Brightness.light), home: const Scaffold(body: SizedBox(), bottomNavigationBar: PulseBottomNavigation(currentPath: '/home'))));
    expect(find.text('home'), findsOneWidget);
    expect(find.text('challenges'), findsOneWidget);
    expect(find.text('achievements'), findsOneWidget);
    expect(find.text('profile'), findsOneWidget);
  });
}
