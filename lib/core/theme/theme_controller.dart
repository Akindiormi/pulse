import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

class ThemeController extends Notifier<ThemeMode> {
  static const _key = 'pulse.theme_mode';

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferencesAsync().getString(_key);
    if (prefs == null) return;
    final mode = switch (prefs) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    state = mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await SharedPreferencesAsync().setString(_key, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> toggle() async => setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}
