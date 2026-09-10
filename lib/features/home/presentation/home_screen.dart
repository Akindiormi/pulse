import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/trusted_challenge_backend.dart';
import '../../../core/motion/pulse_motion_state.dart';
import '../../../core/widgets/pulse_card.dart';
import '../../../core/widgets/pulse_streak.dart';
import '../../../core/widgets/pulse_states.dart';
import '../../../models/task_model.dart';
import '../application/home_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _quickAddController = TextEditingController();
  bool _adding = false;
  @override
  void dispose() { _quickAddController.dispose(); super.dispose(); }

  Future<void> _addTask() async {
    final title = _quickAddController.text.trim();
    if (title.isEmpty || _adding) return;
    setState(() => _adding = true);
    try { await ref.read(homeControllerProvider.notifier).addTask(title); if (mounted) _quickAddController.clear(); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
    finally { if (mounted) setState(() => _adding = false); }
  }

  Future<void> _complete(Task task) async {
    try {
      final result = await ref.read(homeControllerProvider.notifier).completeTask(task.id);
      if (mounted && result?.completed == true) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('+${result!.xpAwarded} XP')));
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); }
  }

  void _focusTask(Task task) {
    context.push('/focus?taskId=${Uri.encodeQueryComponent(task.id)}');
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeControllerProvider);
    return home.when(
      loading: () => const _HomeLoading(),
      error: (error, _) => _HomeError(error: error, onRetry: () => ref.read(homeControllerProvider.notifier).retry()),
      data: (data) => _HomeLoaded(data: data, quickAddController: _quickAddController, adding: _adding, onAdd: _addTask, onComplete: _complete, onFocus: _focusTask, onRefresh: () => ref.read(homeControllerProvider.notifier).retry()),
    );
  }
}

class _HomeLoaded extends StatelessWidget {
  const _HomeLoaded({required this.data, required this.quickAddController, required this.adding, required this.onAdd, required this.onComplete, required this.onFocus, required this.onRefresh});
  final HomeViewData data;
  final TextEditingController quickAddController;
  final bool adding;
  final VoidCallback onAdd;
  final Future<void> Function(Task) onComplete;
  final ValueChanged<Task> onFocus;
  final Future<void> Function() onRefresh;

  String _greeting() { final hour = DateTime.now().hour; if (hour < 12) return 'good morning'; if (hour < 17) return 'good afternoon'; return 'good evening'; }
  String _dateLabel() { final now = DateTime.now(); const months = ['january','february','march','april','may','june','july','august','september','october','november','december']; const days = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday']; return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}'; }

  @override
  Widget build(BuildContext context) {
    final firstName = data.user.displayName?.trim().split(' ').first;
    final greeting = firstName == null || firstName.isEmpty ? _greeting() : '${_greeting()}, $firstName';
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 22, 20, 32), children: [
        Text(greeting, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(_dateLabel(), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        PulseStreak(current: data.user.currentStreak, longest: data.user.longestStreak, state: data.user.currentStreak > 0 ? PulseStreakMotionState.active : PulseStreakMotionState.inactive),
        const SizedBox(height: 20),
        _QuickAdd(controller: quickAddController, adding: adding, onSubmit: onAdd),
        const SizedBox(height: 28),
        _Section(title: 'today', children: data.todayTasks.isEmpty ? [_EmptyToday()] : data.todayTasks.map((task) => _TaskTile(task: task, onComplete: () => onComplete(task), onFocus: () => onFocus(task))).toList()),
        if (data.upcomingTasks.isNotEmpty) ...[const SizedBox(height: 26), _Section(title: 'upcoming', children: data.upcomingTasks.map((task) => _TaskTile(task: task, onComplete: () => onComplete(task), onFocus: () => onFocus(task))).toList())],
        if (data.completedTasks.isNotEmpty) ...[const SizedBox(height: 26), _Section(title: 'completed', children: data.completedTasks.take(8).map((task) => _TaskTile(task: task, onComplete: null, onFocus: null)).toList())],
      ]),
    );
  }
}

class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.controller, required this.adding, required this.onSubmit});
  final TextEditingController controller;
  final bool adding;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) => TextField(controller: controller, textInputAction: TextInputAction.done, onSubmitted: (_) => onSubmit(), enabled: !adding, decoration: InputDecoration(hintText: 'what needs to get done?', prefixIcon: const Icon(Icons.add_task_rounded), suffixIcon: IconButton(onPressed: adding ? null : onSubmit, icon: const Icon(Icons.arrow_upward_rounded))));
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 10), ...children]);
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onComplete, required this.onFocus});
  final Task task;
  final VoidCallback? onComplete;
  final VoidCallback? onFocus;

  @override
  Widget build(BuildContext context) {
    final textColor = task.isCompleted ? Theme.of(context).colorScheme.onSurfaceVariant : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PulseCard(
        child: Row(
          children: [
            Checkbox(
              value: task.isCompleted,
              onChanged: task.isCompleted || onComplete == null ? null : (_) => onComplete!(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  color: textColor,
                ),
              ),
            ),
            if (onFocus != null)
              IconButton(
                tooltip: 'focus on task',
                onPressed: onFocus,
                icon: const Icon(Icons.center_focus_strong_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PulseCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_circle_outline_rounded, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12), Text('what’s one thing worth getting done today?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('add it above and let Pulse keep it in view.', style: Theme.of(context).textTheme.bodyMedium)]));
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 28), children: const [PulseCardLoading(height: 28), SizedBox(height: 8), PulseCardLoading(height: 18), SizedBox(height: 18), PulseCardLoading(height: 72), SizedBox(height: 20), PulseCardLoading(height: 56), SizedBox(height: 28), PulseCardLoading(height: 90), PulseCardLoading(height: 90)]);
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) { final unavailable = error is TrustedBackendException && (error as TrustedBackendException).code == TrustedBackendErrorCode.unavailable; if (unavailable) return PulseOfflineState(onRetry: onRetry); final message = error is TrustedBackendException ? (error as TrustedBackendException).message : 'we couldn’t load your tasks.'; return PulseErrorState(message: message, onRetry: onRetry); }
}
