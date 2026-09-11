import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/pulse_tokens.dart';
import '../../../core/motion/pulse_motion_attachment.dart';
import '../../../core/motion/pulse_motion_state.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pulse_card.dart';
import '../../../core/widgets/pulse_states.dart';
import '../application/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    return Scaffold(appBar: AppBar(title: const Text('settings')), body: state.when(loading: () => const _Loading(), error: (_, __) => PulseErrorState(message: 'we couldn’t load your settings. please try again.', onRetry: () => ref.read(settingsControllerProvider.notifier).refresh()), data: (data) => _Content(data: data)));
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(PulseSpace.lg), children: const [PulseCardLoading(height: 170), SizedBox(height: PulseSpace.lg), PulseCardLoading(height: 170), SizedBox(height: PulseSpace.lg), PulseCardLoading(height: 150)]);
}

class _Content extends ConsumerWidget {
  const _Content({required this.data});
  final SettingsViewData data;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    return RefreshIndicator(onRefresh: controller.refresh, child: ListView(padding: const EdgeInsets.fromLTRB(PulseSpace.lg, PulseSpace.md, PulseSpace.lg, PulseSpace.xxxl), children: [
      PulseMotionBoundaryV2(
        intent: PulseMotionIntent.settingsChange,
        state: PulseSettingsMotionState.idle,
        child: _Section(title: 'preferences', children: [
          _SwitchRow(icon: Icons.notifications_none_rounded, title: 'daily challenge reminder', subtitle: _notificationSubtitle(data), value: data.dailyReminderEnabled, enabled: data.reminderDeliveryAvailable || data.permissionStatus != NotificationPermissionStatus.unavailable, onChanged: (value) => _run(() => controller.setDailyReminder(value), ScaffoldMessenger.maybeOf(context))),
          if (!data.reminderDeliveryAvailable) Padding(padding: const EdgeInsets.fromLTRB(PulseSpace.lg, 0, PulseSpace.lg, PulseSpace.md), child: Text('your reminder preference is kept safely, but reminder delivery is not configured yet. no notification will be sent until the trusted notification backend supports scheduling.', style: AppTypography.metadata)),
          _TapRow(icon: Icons.palette_outlined, title: 'appearance', subtitle: _themeLabel(data.themeMode), onTap: () => _showThemePicker(context, ref)),
          _SwitchRow(icon: Icons.motion_photos_off_outlined, title: 'reduced motion', subtitle: data.reducedMotion ? 'nonessential motion is reduced' : 'full Pulse motion', value: data.reducedMotion, onChanged: (value) => _run(() => controller.setReducedMotion(value), ScaffoldMessenger.maybeOf(context))),
        ]),
      ),
      const SizedBox(height: PulseSpace.xl),
      _Section(title: 'account', children: [
        _TapRow(icon: Icons.person_outline_rounded, title: 'profile', subtitle: 'your identity and Pulse journey', onTap: () => context.push('/profile')),
        _TapRow(icon: Icons.logout_rounded, title: 'sign out', subtitle: 'sign out of this account', onTap: () => _confirmSignOut(context, controller)),
        _TapRow(icon: Icons.delete_outline_rounded, title: 'delete account', subtitle: 'permanently remove your account', destructive: true, onTap: () => _confirmDelete(context, controller)),
      ]),
      const SizedBox(height: PulseSpace.xl),
      _Section(title: 'about', children: const [
        _InfoRow(title: 'Pulse', subtitle: 'small actions, real progress.'),
        _InfoRow(title: 'version', subtitle: '0.1.0+1'),
        _InfoRow(title: 'privacy', subtitle: 'no legal destination is configured yet'),
        _InfoRow(title: 'terms', subtitle: 'no legal destination is configured yet'),
      ]),
    ]));
  }

  String _notificationSubtitle(SettingsViewData data) {
    if (data.permissionStatus == NotificationPermissionStatus.denied) return 'notifications are blocked by your device';
    if (data.permissionStatus == NotificationPermissionStatus.unavailable) return 'notification service unavailable';
    if (data.dailyReminderEnabled && !data.reminderDeliveryAvailable) return 'preference on · delivery not configured';
    if (data.permissionStatus == NotificationPermissionStatus.notDetermined) return 'permission will be requested when enabled';
    if (data.permissionStatus == NotificationPermissionStatus.provisional) return data.dailyReminderEnabled ? 'enabled with provisional permission' : 'available';
    return data.dailyReminderEnabled ? 'enabled' : 'off';
  }

  String _themeLabel(ThemeMode mode) => switch (mode) { ThemeMode.system => 'system', ThemeMode.light => 'light', ThemeMode.dark => 'dark' };

  Future<void> _showThemePicker(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final current = data.themeMode;
    final selected = await showModalBottomSheet<ThemeMode>(context: context, showDragHandle: true, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: ThemeMode.values.map((mode) => RadioListTile<ThemeMode>(value: mode, groupValue: current, title: Text(_themeLabel(mode)), onChanged: (value) => Navigator.pop(context, value))).toList())));
    if (selected != null && selected != current) await _run(() => ref.read(settingsControllerProvider.notifier).setTheme(selected), messenger);
  }

  Future<void> _confirmSignOut(BuildContext context, SettingsController controller) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('sign out?'), content: const Text('you’ll need to sign in again to continue your Pulse journey.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('sign out'))]));
    if (ok == true) await _run(controller.signOut, messenger);
  }

  Future<void> _confirmDelete(BuildContext context, SettingsController controller) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('delete account?'), content: const Text('this is permanent. Pulse will ask the current authentication service to delete your account. profile data will be removed through the trusted deletion workflow.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('delete account'))]));
    if (ok == true) await _run(controller.deleteAccount, messenger);
  }

  Future<void> _run(Future<void> Function() action, ScaffoldMessengerState? messenger) async { try { await action(); } catch (error) { if (messenger == null || !messenger.mounted) return; final message = error is SettingsException ? error.message : 'we couldn’t save that setting. please try again.'; messenger.showSnackBar(SnackBar(content: Text(message))); } }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Semantics(container: true, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTypography.metadata.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: PulseSpace.sm), PulseCard(child: Column(children: children))]));
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged, this.enabled = true});
  final IconData icon;
  final String title, subtitle;
  final bool value, enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(label: '$title, ${value ? 'on' : 'off'}. $subtitle', toggled: value, child: ListTile(minVerticalPadding: PulseSpace.sm, leading: Icon(icon), title: Text(title), subtitle: Text(subtitle), trailing: Switch(value: value, onChanged: enabled ? onChanged : null)));
}

class _TapRow extends StatelessWidget {
  const _TapRow({required this.icon, required this.title, required this.subtitle, required this.onTap, this.destructive = false});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) => Semantics(button: true, label: '$title. $subtitle', child: ListTile(minVerticalPadding: PulseSpace.sm, leading: Icon(icon, color: destructive ? PulseColors.error : null), title: Text(title, style: destructive ? TextStyle(color: PulseColors.error) : null), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => ListTile(title: Text(title), subtitle: Text(subtitle), dense: true);
}
