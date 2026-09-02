import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/di/providers.dart';
import '../../../core/motion/pulse_motion_policy.dart';
import '../../../core/notifications/notification_service.dart';

final settingsControllerProvider = AsyncNotifierProvider<SettingsController, SettingsViewData>(SettingsController.new);

class SettingsViewData {
  const SettingsViewData({
    required this.themeMode,
    required this.reducedMotion,
    required this.dailyReminderEnabled,
    required this.reminderTime,
    required this.permissionStatus,
    required this.reminderDeliveryAvailable,
  });

  final ThemeMode themeMode;
  final bool reducedMotion;
  final bool dailyReminderEnabled;
  final TimeOfDay reminderTime;
  final NotificationPermissionStatus permissionStatus;
  final bool reminderDeliveryAvailable;

  SettingsViewData copyWith({
    ThemeMode? themeMode,
    bool? reducedMotion,
    bool? dailyReminderEnabled,
    TimeOfDay? reminderTime,
    NotificationPermissionStatus? permissionStatus,
    bool? reminderDeliveryAvailable,
  }) => SettingsViewData(
        themeMode: themeMode ?? this.themeMode,
        reducedMotion: reducedMotion ?? this.reducedMotion,
        dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
        reminderTime: reminderTime ?? this.reminderTime,
        permissionStatus: permissionStatus ?? this.permissionStatus,
        reminderDeliveryAvailable: reminderDeliveryAvailable ?? this.reminderDeliveryAvailable,
      );
}

class SettingsController extends AsyncNotifier<SettingsViewData> {
  static const _prefs = SharedPreferencesAsync();
  static const _reducedMotionKey = 'pulse.reduced_motion';
  static const _reminderEnabledKey = 'pulse.daily_reminder_enabled';
  static const _reminderHourKey = 'pulse.daily_reminder_hour';
  static const _reminderMinuteKey = 'pulse.daily_reminder_minute';

  UserRepositoryProxy get _userRepository => UserRepositoryProxy(ref.read(userRepositoryProvider));

  @override
  Future<SettingsViewData> build() async {
    final reducedMotion = await _prefs.getBool(_reducedMotionKey) ?? false;
    PulseMotionPolicy.userReducedMotion = reducedMotion;

    final enabled = await _prefs.getBool(_reminderEnabledKey) ?? false;
    final hour = await _prefs.getInt(_reminderHourKey) ?? 9;
    final minute = await _prefs.getInt(_reminderMinuteKey) ?? 0;
    final permission = await ref.read(notificationServiceProvider).getPermissionStatus();
    final auth = await ref.read(authServiceProvider).authStateChanges.first;
    var serverEnabled = enabled;
    if (auth.uid != null) {
      try {
        final user = await ref.read(userRepositoryProvider).getUser(auth.uid!);
        final raw = user?['notificationPreferences'];
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          final value = map['dailyChallengeReminder'];
          if (value is bool) serverEnabled = value;
        }
      } catch (_) {
        // Keep local state visible; writes still surface errors to the user.
      }
    }
    return SettingsViewData(
      themeMode: ref.read(themeModeValueProvider),
      reducedMotion: reducedMotion,
      dailyReminderEnabled: serverEnabled,
      reminderTime: TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59)),
      permissionStatus: permission,
      reminderDeliveryAvailable: false,
    );
  }

  Future<void> setTheme(ThemeMode mode) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(themeMode: mode));
    try {
      await ref.read(themeControllerProvider.notifier).setMode(mode);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
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
      rethrow;
    }
  }

  Future<void> setDailyReminder(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null || authUid == null) return;
    if (enabled && current.permissionStatus == NotificationPermissionStatus.denied) {
      throw const SettingsException('notifications are blocked by the device. enable them in system settings before turning on reminders.');
    }
    if (enabled && current.permissionStatus == NotificationPermissionStatus.notDetermined) {
      await ref.read(notificationServiceProvider).requestPermission();
      final permission = await ref.read(notificationServiceProvider).getPermissionStatus();
      if (permission == NotificationPermissionStatus.denied || permission == NotificationPermissionStatus.unavailable) {
        state = AsyncData(current.copyWith(permissionStatus: permission));
        throw const SettingsException('notifications are not available on this device right now.');
      }
      state = AsyncData(current.copyWith(permissionStatus: permission));
    }
    final previous = state.valueOrNull ?? current;
    state = AsyncData(previous.copyWith(dailyReminderEnabled: enabled));
    try {
      if (enabled) {
        await ref.read(notificationServiceProvider).scheduleDailyChallengeReminder(hour: previous.reminderTime.hour, minute: previous.reminderTime.minute);
      } else {
        await ref.read(notificationServiceProvider).cancelDailyChallengeReminder();
      }
      await _prefs.setBool(_reminderEnabledKey, enabled);
      await _saveNotificationPreference(enabled: enabled, time: previous.reminderTime);
    } on UnsupportedError {
      state = AsyncData(previous.copyWith(dailyReminderEnabled: false, reminderDeliveryAvailable: false));
      throw const SettingsException('the daily reminder preference is ready, but reminder delivery is not configured in the current notification backend.');
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (!current.reminderDeliveryAvailable) {
      throw const SettingsException('reminder time cannot be changed until daily reminder delivery is configured.');
    }
    await _prefs.setInt(_reminderHourKey, time.hour);
    await _prefs.setInt(_reminderMinuteKey, time.minute);
    state = AsyncData(current.copyWith(reminderTime: time));
    if (current.dailyReminderEnabled) {
      await ref.read(notificationServiceProvider).scheduleDailyChallengeReminder(hour: time.hour, minute: time.minute);
      await _saveNotificationPreference(enabled: true, time: time);
    }
  }

  Future<void> refresh() async => state = const AsyncLoading<SettingsViewData>().copyWithPrevious(state)..value = await build();

  Future<void> requestNotificationPermission() async {
    await ref.read(notificationServiceProvider).requestPermission();
    final permission = await ref.read(notificationServiceProvider).getPermissionStatus();
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(permissionStatus: permission));
  }

  Future<void> signOut() => ref.read(authServiceProvider).signOut();
  Future<void> deleteAccount() => ref.read(authServiceProvider).deleteAccount();

  String? get authUid => ref.read(authServiceProvider).authStateChanges.isBroadcast ? null : null;

  Future<void> _saveNotificationPreference({required bool enabled, required TimeOfDay time}) async {
    final auth = await ref.read(authServiceProvider).authStateChanges.first;
    final uid = auth.uid;
    if (uid == null) throw const SettingsException('your session is no longer available. please sign in again.');
    await ref.read(userRepositoryProvider).updatePreferences(uid: uid, preferences: {
      'dailyChallengeReminder': enabled,
      'reminderHour': time.hour,
      'reminderMinute': time.minute,
    });
  }
}

class SettingsException implements Exception {
  const SettingsException(this.message);
  final String message;
  @override
  String toString() => message;
}

// Small adapter keeps tests and the controller independent from concrete repository types.
class UserRepositoryProxy {
  UserRepositoryProxy(this.repository);
  final dynamic repository;
}

final themeModeValueProvider = Provider<ThemeMode>((ref) => ref.watch(themeControllerProvider));
