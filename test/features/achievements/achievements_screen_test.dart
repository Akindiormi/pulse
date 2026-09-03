import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/core/motion/pulse_events.dart';
import 'package:pulse/core/motion/pulse_motion_state.dart';
import 'package:pulse/core/theme/app_theme.dart';
import 'package:pulse/features/achievements/application/achievements_controller.dart';
import 'package:pulse/features/achievements/presentation/achievements_screen.dart';
import 'package:pulse/features/achievements/data/achievement_definitions.dart';
import 'package:pulse/models/achievement_model.dart';
import 'package:pulse/models/user_model.dart';

UserModel _user({int xp = 165, int level = 2, int streak = 3, int longest = 7, int completed = 42, Set<String> unlocked = const {'FIRST_STEP'}}) => UserModel(uid: 'u1', xp: xp, level: level, currentStreak: streak, longestStreak: longest, totalActivities: completed, unlockedAchievements: unlocked);

AchievementsViewData _data({UserModel? user, Set<String> newly = const {}}) {
  final model = user ?? _user();
  final unlocked = model.unlockedAchievements;
  final items = achievementDefinitions.map((definition) => AchievementItem(definition: definition, unlocked: unlocked.contains(definition.id), progress: AchievementProgress(current: definition.type == AchievementType.streak ? model.currentStreak : definition.type == AchievementType.activityCount ? model.totalActivities : model.completedCategories.length, target: definition.threshold))).toList();
  return AchievementsViewData(user: model, items: items, newlyUnlockedIds: newly);
}

Widget _app(AchievementsViewData data) => ProviderScope(overrides: [achievementsControllerProvider.overrideWith(() => _FakeAchievementsController(data))], child: MaterialApp(theme: buildAppTheme(Brightness.light), home: const AchievementsScreen()));

void main() {
  testWidgets('renders progression and locked/unlocked collection', (tester) async {
    await tester.pumpWidget(_app(_data()));
    await tester.pump();
    expect(find.text('level 2'), findsOneWidget);
    expect(find.text('165 XP'), findsOneWidget);
    expect(find.text('3 days'), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('First Step'), findsOneWidget);
    expect(find.text('unlocked'), findsOneWidget);
    expect(find.text('Week Warrior'), findsOneWidget);
  });

  testWidgets('newly unlocked state is presented without inventing rewards', (tester) async {
    await tester.pumpWidget(_app(_data(newly: const {'WEEK_WARRIOR'})));
    await tester.pump();
    expect(find.bySemanticsLabel('newlyUnlocked'), findsOneWidget);
    await tester.tap(find.text('Week Warrior'));
    await tester.pumpAndSettle();
    expect(find.text('newly unlocked'), findsOneWidget);
    expect(find.text('+100 XP'), findsOneWidget);
  });

  testWidgets('locked detail shows reliable progress', (tester) async {
    await tester.pumpWidget(_app(_data(user: _user(unlocked: const {'FIRST_STEP'}, streak: 3))));
    await tester.pump();
    await tester.tap(find.text('Week Warrior'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 7'), findsOneWidget);
    expect(find.text('Reach a 7-day streak'), findsOneWidget);
  });

  test('achievement unlock event maps to presentation state without unlocking locally', () async {
    final container = ProviderContainer(
      overrides: [achievementsControllerProvider.overrideWith(() => _FakeAchievementsController(_data()))],
    );
    addTearDown(container.dispose);
    await container.read(achievementsControllerProvider.future);
    final controller = container.read(achievementsControllerProvider.notifier);
    controller.applyAchievementUnlocked(const AchievementUnlockedEvent('WEEK_WARRIOR'));
    final result = container.read(achievementsControllerProvider).valueOrNull!;
    expect(result.newlyUnlockedIds, contains('WEEK_WARRIOR'));
    expect(result.user.unlockedAchievements, isNot(contains('WEEK_WARRIOR')));
  });

  test('motion vocabulary contains achievement and progression states', () {
    expect(PulseAchievementMotionState.values, containsAll([PulseAchievementMotionState.locked, PulseAchievementMotionState.unlocked, PulseAchievementMotionState.newlyUnlocked, PulseAchievementMotionState.milestone]));
    expect(PulseProgressMotionState.values, containsAll([PulseProgressMotionState.unchanged, PulseProgressMotionState.xpGained, PulseProgressMotionState.levelUp]));
    expect(PulseStreakMotionState.values, containsAll([PulseStreakMotionState.inactive, PulseStreakMotionState.active, PulseStreakMotionState.increased, PulseStreakMotionState.maintained, PulseStreakMotionState.milestone, PulseStreakMotionState.broken]));
  });
}

class _FakeAchievementsController extends AchievementsController {
  _FakeAchievementsController(this.initial);
  final AchievementsViewData initial;
  @override Future<AchievementsViewData> build() async => initial;
}
