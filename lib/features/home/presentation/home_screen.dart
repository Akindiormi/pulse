import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/trusted_challenge_backend.dart';
import '../../../core/motion/pulse_motion_state.dart';
import '../../../core/widgets/pulse_card.dart';
import '../../../core/widgets/pulse_streak.dart';
import '../../../core/widgets/pulse_states.dart';
import '../../../models/focus_session_model.dart';
import '../../../models/project_model.dart';
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

  void _focusTask(Task task) => context.push('/focus?taskId=${Uri.encodeQueryComponent(task.id)}');

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
  String _focusLabel(int seconds) { final minutes = seconds ~/ 60; if (minutes < 1) return '${seconds}s focused'; return '${minutes}m focused'; }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = data.user.displayName?.trim().split(' ').first;
    final greeting = firstName == null || firstName.isEmpty ? _greeting() : '${_greeting()}, $firstName';
    final next = data.nextTask;
    final activeFocus = data.activeFocusSession;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          Text(greeting, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(_dateLabel(), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          PulseStreak(current: data.user.currentStreak, longest: data.user.longestStreak, state: data.user.currentStreak > 0 ? PulseStreakMotionState.active : PulseStreakMotionState.inactive),
          const SizedBox(height: 20),
          if (activeFocus != null) ...[
            _FocusResumeCard(session: activeFocus, onResume: () => activeFocus.taskId == null ? context.push('/focus') : context.push('/focus?taskId=${Uri.encodeQueryComponent(activeFocus.taskId!)}')),
            const SizedBox(height: 20),
          ] else if (next != null) ...[
            _NextActionCard(task: next, onFocus: () => onFocus(next)),
            const SizedBox(height: 20),
          ],
          _TodaySummary(data: data, focusLabel: _focusLabel(data.focusTodaySeconds)),
          const SizedBox(height: 20),
          _QuickAdd(controller: quickAddController, adding: adding, onSubmit: onAdd),
          const SizedBox(height: 28),
          _Section(title: 'today', children: data.todayTasks.isEmpty ? [_EmptyToday()] : data.todayTasks.map((task) => _TaskTile(task: task, onComplete: () => onComplete(task), onFocus: () => onFocus(task))).toList()),
          if (data.projects.isNotEmpty) ...[
            const SizedBox(height: 28),
            _ProjectMovement(data: data),
          ],
          if (data.upcomingTasks.isNotEmpty) ...[const SizedBox(height: 26), _Section(title: 'upcoming', children: data.upcomingTasks.map((task) => _TaskTile(task: task, onComplete: () => onComplete(task), onFocus: () => onFocus(task))).toList())],
          if (data.completedToday.isNotEmpty) ...[const SizedBox(height: 26), _Section(title: 'done today', children: data.completedToday.take(8).map((task) => _TaskTile(task: task, onComplete: null, onFocus: null)).toList())],
        ],
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({required this.task, required this.onFocus});
  final Task task;
  final VoidCallback onFocus;
  @override
  Widget build(BuildContext context) => PulseCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('what’s next', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(task.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 14), FilledButton.icon(onPressed: onFocus, icon: const Icon(Icons.center_focus_strong_rounded), label: const Text('start focus'))]));
}

class _FocusResumeCard extends StatelessWidget {
  const _FocusResumeCard({required this.session, required this.onResume});
  final FocusSession session;
  final VoidCallback onResume;
  @override
  Widget build(BuildContext context) => PulseCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('focus in progress', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(session.isPaused ? 'paused — ready when you are' : 'you have an active session', style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 12), FilledButton.icon(onPressed: onResume, icon: const Icon(Icons.play_arrow_rounded), label: Text(session.isPaused ? 'resume focus' : 'continue focus'))]));
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.data, required this.focusLabel});
  final HomeViewData data;
  final String focusLabel;
  @override
  Widget build(BuildContext context) => PulseCard(child: Row(children: [Expanded(child: _Metric(label: 'focus today', value: focusLabel)), Expanded(child: _Metric(label: 'done today', value: '${data.completedToday.length}'))]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))]);
}

class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.controller, required this.adding, required this.onSubmit});
  final TextEditingController controller;
  final bool adding;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) => TextField(controller: controller, textInputAction: TextInputAction.done, onSubmitted: (_) => onSubmit(), enabled: !adding, decoration: InputDecoration(hintText: 'what needs to get done?', prefixIcon: const Icon(Icons.add_task_rounded), suffixIcon: IconButton(tooltip: 'add task', onPressed: adding ? null : onSubmit, icon: const Icon(Icons.arrow_upward_rounded))));
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 10), ...children]);
}

class _ProjectMovement extends StatelessWidget {
  const _ProjectMovement({required this.data});
  final HomeViewData data;

  @override
  Widget build(BuildContext context) {
    final projects = [...data.projects]
      ..sort((a, b) {
        if (a.status == b.status) return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (a.status == ProjectStatus.active) return -1;
        if (b.status == ProjectStatus.active) return 1;
        if (a.status == ProjectStatus.completed) return -1;
        return 1;
      });
    final visible = projects.take(4).toList(growable: false);
    return _Section(
      title: 'projects',
      children: visible.map((project) {
        final completed = data.projectCompletedTaskCount(project.id);
        final open = data.projectOpenTaskCount(project.id);
        final total = completed + open;
        final progress = total == 0 ? null : completed / total;
        final status = project.status == ProjectStatus.completed
            ? 'complete'
            : progress == null
                ? 'no tasks yet'
                : '$completed of $total tasks done';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PulseCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(status, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      if (progress != null && project.status != ProjectStatus.completed) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(value: progress, minHeight: 5),
                        ),
                      ],
                    ],
                  ),
                ),
                if (project.status == ProjectStatus.completed) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.check_circle_outline_rounded, semanticLabel: '${project.name} completed'),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onComplete, required this.onFocus});
  final Task task;
  final VoidCallback? onComplete;
  final VoidCallback? onFocus;
  @override
  Widget build(BuildContext context) {
    final textColor = task.isCompleted ? Theme.of(context).colorScheme.onSurfaceVariant : null;
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: PulseCard(child: Row(children: [Checkbox(value: task.isCompleted, onChanged: task.isCompleted || onComplete == null ? null : (_) => onComplete!(), semanticLabel: task.isCompleted ? '${task.title} completed' : 'complete ${task.title}'), const SizedBox(width: 8), Expanded(child: Text(task.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(decoration: task.isCompleted ? TextDecoration.lineThrough : null, color: textColor))), if (onFocus != null) IconButton(tooltip: 'focus on task', onPressed: onFocus, icon: const Icon(Icons.center_focus_strong_rounded))])));
  }
}

class _EmptyToday extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PulseCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_circle_outline_rounded, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12), Text('nothing scheduled for today', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('add a task above when you know what needs to get done.', style: Theme.of(context).textTheme.bodyMedium)]));
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
  Widget build(BuildContext context) { final unavailable = error is TrustedBackendException && (error as TrustedBackendException).code == TrustedBackendErrorCode.unavailable; if (unavailable) return PulseOfflineState(onRetry: onRetry); final message = error is TrustedBackendException ? (error as TrustedBackendException).message : 'we couldn’t load your Pulse.'; return PulseErrorState(message: message, onRetry: onRetry); }
}
