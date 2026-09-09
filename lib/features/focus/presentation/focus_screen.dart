import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/focus_session_model.dart';
import '../application/focus_controller.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key, this.taskId, this.plannedDurationSeconds});
  final String? taskId;
  final int? plannedDurationSeconds;
  @override ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  int minutes = 25;
  String format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${d.inMinutes.toString().padLeft(2, '0')}:$s';
  }
  @override Widget build(BuildContext context) {
    final async = ref.watch(focusControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('focus'), actions: [IconButton(tooltip: 'history', onPressed: () => context.push('/focus/history'), icon: const Icon(Icons.history_rounded))]),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: FilledButton(onPressed: () => ref.invalidate(focusControllerProvider), child: const Text('try again'))),
        data: (state) => ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 36), children: [
          Text('intentional work', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(state.session == null ? 'choose a session and get to work.' : state.status.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20), child: Column(children: [Text(format(state.elapsedDuration), style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('actual focused time')])),
          const SizedBox(height: 20),
          if (state.session == null || state.session!.isTerminal) ...[
            Text('session length', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [15, 25, 45, 60, 90].map((v) => ChoiceChip(label: Text('$v min'), selected: minutes == v, onSelected: (_) => setState(() => minutes = v))).toList()),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: state.actionInProgress ? null : () => ref.read(focusControllerProvider.notifier).start(taskId: widget.taskId, plannedDurationSeconds: widget.plannedDurationSeconds ?? minutes * 60), icon: const Icon(Icons.play_arrow_rounded), label: const Text('start focus')),
          ] else if (state.session!.isRunning) ...[
            Row(children: [Expanded(child: FilledButton.icon(onPressed: state.actionInProgress ? null : () => ref.read(focusControllerProvider.notifier).pause(), icon: const Icon(Icons.pause_rounded), label: const Text('pause'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: state.actionInProgress ? null : () => ref.read(focusControllerProvider.notifier).complete(), icon: const Icon(Icons.check_rounded), label: const Text('complete')))]),
            TextButton.icon(onPressed: state.actionInProgress ? null : () => ref.read(focusControllerProvider.notifier).cancel(), icon: const Icon(Icons.close_rounded), label: const Text('cancel session')),
          ] else if (state.session!.isPaused) ...[
            Row(children: [Expanded(child: FilledButton.icon(onPressed: state.actionInProgress ? null : () => ref.read(focusControllerProvider.notifier).resume(), icon: const Icon(Icons.play_arrow_rounded), label: const Text('resume'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: state.actionInProgress ? null : () => ref.read(focusControllerProvider.notifier).complete(), icon: const Icon(Icons.check_rounded), label: const Text('complete')))]),
            TextButton.icon(onPressed: state.actionInProgress ? null : () => ref.read(focusControllerProvider.notifier).cancel(), icon: const Icon(Icons.close_rounded), label: const Text('cancel session')),
          ] else ...[
            FilledButton.icon(onPressed: state.actionInProgress ? null : () => ref.read(focusControllerProvider.notifier).start(plannedDurationSeconds: minutes * 60), icon: const Icon(Icons.replay_rounded), label: const Text('start another session')),
          ],
          if (state.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(state.error!.message, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
      ),
    );
  }
}
