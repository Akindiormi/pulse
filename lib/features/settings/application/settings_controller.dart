import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/database/repositories.dart';
import '../../../core/di/providers.dart';
import '../../../core/motion/pulse_motion_policy.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/theme_controller.dart';

final settingsControllerProvider = AsyncNotifierProvider<SettingsController, SettingsViewData>(SettingsController.new);

class SettingsViewData {
  const SettingsViewData({required this.themeMode, required this.reducedMotion, required this.dailyReminderEnabled, required this.reminderTime, required this.permissionStatus, required this.reminderDeliveryAvailable});
  final ThemeMode themeMode;
  final bool reducedMotion;
  final bool dailyReminderEnabled;
  final TimeOfDay reminderTime;
  final NotificationPermissionStatus permissionStatus;
  final bool reminderDeliveryAvailable;
  SettingsViewData copyWith({ThemeMode? themeMode, bool? reducedMotion, bool? dailyReminderEnabled, TimeOfDay? reminderTime, NotificationPermissionStatus? permissionStatus, bool? reminderDeliveryAvailable}) => SettingsViewData(themeMode: themeMode ?? this.themeMode, reducedMotion: reducedMotion ?? this.reducedMotion, dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled, reminderTime: reminderTime ?? this.reminderTime, permissionStatus: permissionStatus ?? this.permissionStatus, reminderDeliveryAvailable: reminderDeliveryAvailable ?? this.reminderDeliveryAvailable);
}

class SettingsController extends AsyncNotifier<SettingsViewData> {
  static final _prefs = SharedPreferencesAsync();
  static const _reducedMotionKey = 'pulse.reduced_motion';
  static const _reminderEnabledKey = 'pulse.daily_reminder_enabled';
  static const _reminderHourKey = 'pulse.daily_reminder_hour';
  static const _reminderMinuteKey = 'pulse.daily_reminder_minute';

  @override
  Future<SettingsViewData> build() async {
    final reducedMotion = await _prefs.getBool(_reducedMotionKey) ?? false;
    PulseMotionPolicy.userReducedMotion = reducedMotion;
    final enabled = await _prefs.getBool(_reminderEnabledKey) ?? false;
    final hour = (await _prefs.getInt(_reminderHourKey) ?? 9).clamp(0, 23);
    final minute = (await _prefs.getInt(_reminderMinuteKey) ?? 0).clamp(0, 59);
    final notification = ref.read(notificationServiceProvider);
    final permission = await notification.getPermissionStatus();
    var serverEnabled = enabled;
    final auth = await ref.read(authServiceProvider).authStateChanges.first;
    if (auth.uid != null) {
      try {
        final user = await ref.read(userRepositoryProvider).getUser(auth.uid!);
        final raw = user?['notificationPreferences'];
        if (raw is Map && raw['dailyChallengeReminder'] is bool) serverEnabled = raw['dailyChallengeReminder'] as bool;
      } catch (_) {}
    }
    return SettingsViewData(themeMode: ref.read(themeControllerProvider), reducedMotion: reducedMotion, dailyReminderEnabled: serverEnabled, reminderTime: TimeOfDay(hour: hour, minute: minute), permissionStatus: permission, reminderDeliveryAvailable: false);
  }

  Future<void> setTheme(ThemeMode mode) async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      await ref.read(themeControllerProvider.notifier).setMode(mode);
      state = AsyncData(current.copyWith(themeMode: mode));
    } catch (_) {
      state = AsyncData(current);
      throw const SettingsException('we couldn’t save your appearance preference.');
    }
  }

  Future<void> setReducedMotion(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(reducedMotion: enabled));
    PulseMotionPolicy.userReducedMotion = enabled;
    try {
      await _prefs.setBool(_reducedMotionKey, enabled);
    } catch (_) {
      PulseMotionPolicy.userReducedMotion = current.reducedMotion;
      state = AsyncData(current);
      throw const SettingsException('we couldn’t save your motion preference.');
    }
  }

  Future<void> setDailyReminder(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (enabled && current.permissionStatus == NotificationPermissionStatus.denied) throw const SettingsException('notifications are blocked by the device. enable them in system settings first.');
    if (enabled && current.permissionStatus == NotificationPermissionStatus.notDetermined) {
      await requestNotificationPermission();
      final refreshed = state.valueOrNull ?? current;
      if (refreshed.permissionStatus == NotificationPermissionStatus.denied || refreshed.permissionStatus == NotificationPermissionStatus.unavailable) throw const SettingsException('notifications are not available on this device right now.');
    }
    final previous = state.valueOrNull ?? current;
    try {
      if (enabled) {
        await ref.read(notificationServiceProvider).scheduleDailyChallengeReminder(hour: previous.reminderTime.hour, minute: previous.reminderTime.minute);
      } else {
        await ref.read(notificationServiceProvider).cancelDailyChallengeReminder();
      }
      await _prefs.setBool(_reminderEnabledKey, enabled);
      await _saveNotificationPreference(enabled: enabled, time: previous.reminderTime);
      state = AsyncData(previous.copyWith(dailyReminderEnabled: enabled));
    } on UnsupportedError {
      state = AsyncData(previous.copyWith(dailyReminderEnabled: false, reminderDeliveryAvailable: false));
      throw const SettingsException('daily reminder delivery is not configured in the current notification backend yet.');
    } catch (_) {
      state = AsyncData(previous);
      throw const SettingsException('we couldn’t save your reminder preference. please try again.');
    }
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    final current = state.valueOrNull;
    if (current == null || !current.reminderDeliveryAvailable) throw const SettingsException('reminder time will be available when daily reminder delivery is configured.');
    try {
      await _prefs.setInt(_reminderHourKey, time.hour);
      await _prefs.setInt(_reminderMinuteKey, time.minute);
      if (current.dailyReminderEnabled) await ref.read(notificationServiceProvider).scheduleDailyChallengeReminder(hour: time.hour, minute: time.minute);
      if (current.dailyReminderEnabled) await _saveNotificationPreference(enabled: true, time: time);
      state = AsyncData(current.copyWith(reminderTime: time));
    } catch (_) {
      throw const SettingsException('we couldn’t save the reminder time.');
    }
  }

  Future<void> requestNotificationPermission() async {
    final service = ref.read(notificationServiceProvider);
    await service.requestPermission();
    final permission = await service.getPermissionStatus();
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(permissionStatus: permission));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try { state = AsyncData(await build()); } catch (error, stack) { state = AsyncError(error, stack); }
  }
  Future<void> signOut() => ref.read(authServiceProvider).signOut();
  Future<void> deleteAccount() => ref.read(authServiceProvider).deleteAccount();

  Future<void> _saveNotificationPreference({required bool enabled, required TimeOfDay time}) async {
    final auth = await ref.read(authServiceProvider).authStateChanges.first;
    final uid = auth.uid;
    if (uid == null) throw const SettingsException('your session is no longer available. please sign in again.');
    await ref.read(userRepositoryProvider).updatePreferences(uid: uid, preferences: {'dailyChallengeReminder': enabled, 'reminderHour': time.hour, 'reminderMinute': time.minute});
  }
}

class SettingsException implements Exception {
  const SettingsException(this.message);
  final String message;
  @override String toString() => message;
}
