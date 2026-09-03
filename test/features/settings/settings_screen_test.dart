import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pulse/core/notifications/notification_service.dart';
import 'package:pulse/features/settings/application/settings_controller.dart';
import 'package:pulse/features/settings/presentation/settings_screen.dart';

void main() {
  const initial = SettingsViewData(
    themeMode: ThemeMode.system,
    reducedMotion: false,
    dailyReminderEnabled: false,
    reminderTime: TimeOfDay(hour: 9, minute: 0),
    permissionStatus: NotificationPermissionStatus.authorized,
    reminderDeliveryAvailable: false,
  );

  testWidgets('renders settings preferences and accessibility state', (tester) async {
    await tester.pumpWidget(_app(FakeSettingsController(initial)));
    await tester.pump();
    expect(find.text('settings'), findsOneWidget);
    expect(find.text('daily challenge reminder'), findsOneWidget);
    expect(find.text('appearance'), findsOneWidget);
    expect(find.text('system'), findsOneWidget);
    expect(find.text('reduced motion'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('daily challenge reminder, off')), findsOneWidget);
  });

  testWidgets('renders safe notification unavailable message', (tester) async {
    final data = initial.copyWith(permissionStatus: NotificationPermissionStatus.unavailable);
    await tester.pumpWidget(_app(FakeSettingsController(data)));
    await tester.pump();
    expect(find.text('notification service unavailable'), findsOneWidget);
    expect(find.textContaining('reminder delivery is not configured yet'), findsOneWidget);
  });

  testWidgets('appearance picker exposes system, light and dark', (tester) async {
    await tester.pumpWidget(_app(FakeSettingsController(initial)));
    await tester.pump();
    await tester.tap(find.text('appearance'));
    await tester.pumpAndSettle();
    expect(find.text('system'), findsNWidgets(2));
    expect(find.text('light'), findsOneWidget);
    expect(find.text('dark'), findsOneWidget);
  });

  testWidgets('account actions require explicit confirmation', (tester) async {
    final controller = FakeSettingsController(initial);
    await tester.pumpWidget(_app(controller));
    await tester.pump();
    await tester.tap(find.text('sign out'));
    await tester.pumpAndSettle();
    expect(find.text('sign out?'), findsOneWidget);
    expect(controller.signOutCalls, 0);
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();
    expect(controller.signOutCalls, 0);
  });

  test('settings state has no authoritative progression fields', () {
    expect(initial.toString(), isNot(contains('xp')));
    expect(initial.toString(), isNot(contains('level')));
    expect(initial.toString(), isNot(contains('streak')));
    expect(initial.toString(), isNot(contains('achievement')));
  });
}

Widget _app(FakeSettingsController controller) => ProviderScope(
      overrides: [settingsControllerProvider.overrideWith(() => controller)],
      child: const MaterialApp(home: SettingsScreen()),
    );

class FakeSettingsController extends SettingsController {
  FakeSettingsController(this.data);
  final SettingsViewData data;
  int signOutCalls = 0;
  int deleteCalls = 0;

  @override
  Future<SettingsViewData> build() async => data;

  @override
  Future<void> setTheme(ThemeMode mode) async {}

  @override
  Future<void> setReducedMotion(bool enabled) async {}

  @override
  Future<void> setDailyReminder(bool enabled) async {}

  @override
  Future<void> requestNotificationPermission() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  Future<void> deleteAccount() async => deleteCalls++;
}
