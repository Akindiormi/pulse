import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/focus_session_model.dart';
import '../application/focus_history_controller.dart';

class FocusHistoryScreen extends ConsumerWidget {
  const FocusHistoryScreen({super.key});

  String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  int _weekTotal(List<FocusSession> sessions) {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day).subtract(const Duration(days: 6));
    return sessions
        .where((session) => !session.startedAt.toUtc().isBefore(start))
        .fold<int>(0, (sum, session) => sum + session.activeDurationSeconds);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(focusHistoryControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('focus history')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('couldn’t load history'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(focusHistoryControllerProvider), child: const Text('try again')),
            ],
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) return const Center(child: Text('no Focus sessions yet.'));
          final total = sessions.fold<int>(0, (sum, session) => sum + session.activeDurationSeconds);
          final weekTotal = _weekTotal(sessions);
          return RefreshIndicator(
            onRefresh: () => ref.read(focusHistoryControllerProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        value: _duration(weekTotal),
                        label: 'last 7 days',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        value: _duration(total),
                        label: 'all loaded time',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('sessions', style: TextStyle(fontWeight: FontWeight.w700)),
                        Text('${sessions.length}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...sessions.map((session) => _SessionTile(session: session, duration: _duration(session.activeDurationSeconds))),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.duration});
  final FocusSession session;
  final String duration;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: Icon(session.status == FocusSessionStatus.completed ? Icons.check_circle_rounded : Icons.cancel_rounded),
          title: Text(duration, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(session.startedAt.toLocal().toString()),
          trailing: Text(session.status.value),
        ),
      );
}
