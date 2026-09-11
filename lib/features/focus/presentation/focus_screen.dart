import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/focus_controller.dart';
import '../../../core/di/providers.dart';
import '../../../models/focus_session_model.dart';
import '../../onboarding/application/new_user_activation_controller.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key, this.taskId, this.calendarEventId, this.plannedDurationSeconds, this.activation = false});
  final String? taskId;
  final String? calendarEventId;
  final int? plannedDurationSeconds;
  final bool activation;
  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  int _minutes = 25;

  String _format(Duration value) {
    final h = value.inHours;
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${value.inMinutes.toString().padLeft(2, '0')}:$s';
  }

  void _start() {
    final duration = widget.plannedDurationSeconds ?? _minutes * 60;
    ref.read(focusControllerProvider.notifier).start(intent: FocusIntent(plannedDurationSeconds: duration, taskId: widget.taskId, calendarEventId: widget.calendarEventId));
  }

  Future<void> _complete() async {
    if (widget.activation && widget.taskId != null) {
      await ref.read(focusControllerProvider.notifier).complete();
      final result = await ref.read(taskRepositoryProvider).completeTask(taskId: widget.taskId!);
      if (!result.completed && !result.alreadyCompleted) return;
      await ref.read(newUserActivationProvider.notifier).markFocusCompleted();
      if (mounted) context.go('/first-win');
      return;
    }
    await ref.read(focusControllerProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(focusControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('focus'),
        actions: [if (!widget.activation) IconButton(tooltip: 'history', onPressed: () => context.push('/focus/history'), icon: const Icon(Icons.history_rounded))],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: FilledButton(onPressed: () => ref.invalidate(focusControllerProvider), child: Text('try again: $error'))),
        data: (state) => _FocusContent(
          state: state,
          minutes: _minutes,
          onMinutesChanged: (value) => setState(() => _minutes = value),
          onStart: _start,
          onPause: () => ref.read(focusControllerProvider.notifier).pause(),
          onResume: () => ref.read(focusControllerProvider.notifier).resume(),
          onComplete: _complete,
          onCancel: () => ref.read(focusControllerProvider.notifier).cancel(),
          formatter: _format,
          activation: widget.activation,
        ),
      ),
    );
  }
}

class _FocusContent extends StatelessWidget {
  const _FocusContent({required this.state, required this.minutes, required this.onMinutesChanged, required this.onStart, required this.onPause, required this.onResume, required this.onComplete, required this.onCancel, required this.formatter, required this.activation});
  final FocusState state;
  final int minutes;
  final ValueChanged<int> onMinutesChanged;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final String Function(Duration) formatter;
  final bool activation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = state.session;
    final busy = state.actionInProgress || state.isLoading;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      children: [
        Text(activation ? 'your next move' : 'intentional work', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(activation ? 'choose one thing and get it done.' : session == null ? 'choose a session and get to work.' : session.status.value, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 28),
        Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20), child: Column(children: [Text(formatter(state.elapsedDuration), style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text('actual focused time', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))]))),
        const SizedBox(height: 20),
        if (session == null || session.isTerminal) ...[
          if (!activation) ...[Text('session length', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 10), Wrap(spacing: 8, children: [15, 25, 45, 60, 90].map((value) => ChoiceChip(label: Text('$value min'), selected: minutes == value, onSelected: (_) => onMinutesChanged(value))).toList()), const SizedBox(height: 18)],
          FilledButton.icon(onPressed: busy ? null : onStart, icon: const Icon(Icons.play_arrow_rounded), label: Text(activation ? 'start focus' : 'start focus')),
        ],
        if (session?.isRunning == true) ...[
          Row(children: [Expanded(child: FilledButton.icon(onPressed: busy ? null : onPause, icon: const Icon(Icons.pause_rounded), label: const Text('pause'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: busy ? null : onComplete, icon: const Icon(Icons.check_rounded), label: const Text('complete')))]),
          if (!activation) TextButton.icon(onPressed: busy ? null : onCancel, icon: const Icon(Icons.close_rounded), label: const Text('cancel session')),
        ],
        if (session?.isPaused == true) ...[
          Row(children: [Expanded(child: FilledButton.icon(onPressed: busy ? null : onResume, icon: const Icon(Icons.play_arrow_rounded), label: const Text('resume'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: busy ? null : onComplete, icon: const Icon(Icons.check_rounded), label: const Text('complete')))]),
          if (!activation) TextButton.icon(onPressed: busy ? null : onCancel, icon: const Icon(Icons.close_rounded), label: const Text('cancel session')),
        ],
        if (session?.isTerminal == true && !activation) FilledButton.icon(onPressed: busy ? null : onStart, icon: const Icon(Icons.replay_rounded), label: const Text('start another session')),
        if (state.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(state.error!.message, style: TextStyle(color: theme.colorScheme.error))),
      ],
    );
  }
}
