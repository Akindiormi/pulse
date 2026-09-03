import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pulse/features/profile/application/profile_controller.dart';
import 'package:pulse/features/profile/presentation/profile_screen.dart';
import 'package:pulse/models/achievement_model.dart';
import 'package:pulse/models/user_model.dart';

void main() {
  final user = UserModel(uid: 'user-1', displayName: 'Akin Pulse', username: 'akinpulse', totalActivities: 12, currentStreak: 5, longestStreak: 9, xp: 640, level: 3, completedCategories: {'focus', 'health', 'learning'}, unlockedAchievements: {'first_step'});

  testWidgets('renders identity and progression summary', (tester) async {
    final data = ProfileViewData(user: user, achievements: const <AchievementRecord>[]);
    await tester.pumpWidget(_app(FakeProfileController(data)));
    await tester.pumpAndSettle();
    expect(find.text('Akin Pulse'), findsOneWidget);
    expect(find.text('@akinpulse'), findsOneWidget);
    expect(find.text('level 3'), findsOneWidget);
    expect(find.text('640 XP'), findsOneWidget);
    expect(find.text('5 days'), findsOneWidget);
    expect(find.text('9 days'), findsOneWidget);
    expect(find.text('3 categories explored'), findsOneWidget);
    expect(find.text('0 unlocked'), findsOneWidget);
  });

  testWidgets('uses initials fallback when avatar is unavailable', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(FakeProfileController(ProfileViewData(user: user, achievements: const <AchievementRecord>[]))));
      await tester.pumpAndSettle();
      expect(find.text('AP'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^profile avatar for Akin Pulse')), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('keeps long identity text and exposes edit action', (tester) async {
    final longUser = user.copyWith(displayName: 'A very long Pulse display name that should wrap safely');
    final data = ProfileViewData(user: longUser, achievements: const <AchievementRecord>[]);
    await tester.pumpWidget(_app(FakeProfileController(data)));
    await tester.pumpAndSettle();
    expect(find.text(longUser.displayName!), findsOneWidget);
    expect(find.byTooltip('edit profile'), findsOneWidget);
  });

  testWidgets('edit flow calls save once', (tester) async {
    final controller = FakeProfileController(ProfileViewData(user: user, achievements: const <AchievementRecord>[]));
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('edit profile'));
    await tester.pumpAndSettle();
    expect(find.text('edit profile'), findsOneWidget);
    await tester.tap(find.text('save'));
    expect(controller.saveCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test('profile view data exposes authoritative progression and achievement state', () {
    final data = ProfileViewData(user: user, achievements: const <AchievementRecord>[]);
    expect(data.user.xp, 640);
    expect(data.user.level, 3);
    expect(data.user.currentStreak, 5);
    expect(data.user.longestStreak, 9);
    expect(data.user.totalActivities, 12);
    expect(data.user.unlockedAchievements, {'first_step'});
  });
}

Widget _app(FakeProfileController controller) => ProviderScope(
      overrides: [profileControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(home: const ProfileScreen()),
    );

class FakeProfileController extends ProfileController {
  FakeProfileController(this.data);
  final ProfileViewData data;
  int saveCalls = 0;

  @override
  Future<ProfileViewData> build() async => data;

  @override
  Future<bool> saveDisplayName(String value) async {
    saveCalls++;
    editState = ProfileEditState.saved;
    return true;
  }

  @override
  Future<void> refresh() async {}
}
