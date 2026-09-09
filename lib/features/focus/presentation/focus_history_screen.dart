import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/focus_session_model.dart';
import '../application/focus_history_controller.dart';

class FocusHistoryScreen extends ConsumerWidget {
  const FocusHistoryScreen({super.key});
  String _duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
  @override Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(focusHistoryControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('focus history')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('couldn’t load history'), const SizedBox(height: 12), FilledButton(onPressed: () => ref.invalidate(focusHistoryControllerProvider), child: const Text('try again'))])),
        data: (sessions) {
          if (sessions.isEmpty) return const Center(child: Text('no Focus sessions yet.'));
          final total = sessions.fold<int>(0, (sum, session) => sum + session.activeDurationSeconds);
          return RefreshIndicator(onRefresh: () => ref.read(focusHistoryControllerProvider.notifier).refresh(), child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 32), children: [
            Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_duration(total), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 4), const Text('total focused time')]), Text('${sessions.length} sessions', style: Theme.of(context).textTheme.bodyMedium)])),
            const SizedBox(height: 24),
            ...sessions.map((session) => _SessionTile(session: session, duration: _duration(session.activeDurationSeconds))),
          ]));
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.duration});
  final FocusSession session;
  final String duration;
  @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: Icon(session.status == FocusSessionStatus.completed ? Icons.check_circle_rounded : Icons.cancel_rounded), title: Text(duration, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${session.startedAt.toLocal()}'), trailing: Text(session.status.value)));
}
