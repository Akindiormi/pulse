import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/pulse_tokens.dart';
import '../../../core/widgets/pulse_card.dart';
import '../../../models/project_model.dart';
import '../application/progress_controller.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('progress')),
      body: progress.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('couldn’t load progress'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(progressControllerProvider), child: const Text('try again')),
            ],
          ),
        ),
        data: (snapshot) => RefreshIndicator(
          onRefresh: () => ref.read(progressControllerProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(PulseSpace.lg, PulseSpace.lg, PulseSpace.lg, 32),
            children: [
              Text('your progress', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: PulseSpace.xs),
              Text('a live view of what you’ve actually done.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: PulseSpace.lg),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: PulseSpace.sm,
                crossAxisSpacing: PulseSpace.sm,
                childAspectRatio: 1.45,
                children: [
                  _MetricCard(value: '${snapshot.completedTasks}', label: 'tasks completed', icon: Icons.check_circle_outline_rounded),
                  _MetricCard(value: '${snapshot.activeProjects}', label: 'active projects', icon: Icons.folder_copy_outlined),
                  _MetricCard(value: _duration(snapshot.totalFocusSeconds), label: 'focused time', icon: Icons.center_focus_strong_rounded),
                  _MetricCard(value: '${snapshot.completedFocusSessions}', label: 'focus sessions', icon: Icons.timer_outlined),
                ],
              ),
              const SizedBox(height: PulseSpace.sm),
              PulseCard(
                child: Padding(
                  padding: const EdgeInsets.all(PulseSpace.lg),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 28),
                      const SizedBox(width: PulseSpace.md),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${snapshot.user.currentStreak} day streak', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('longest: ${snapshot.user.longestStreak} days', style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: PulseSpace.sm),
              PulseCard(
                child: Padding(
                  padding: const EdgeInsets.all(PulseSpace.lg),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 28),
                      const SizedBox(width: PulseSpace.md),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('level ${snapshot.user.level}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('${snapshot.user.xp} XP', style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: PulseSpace.lg),
              Text('projects', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: PulseSpace.sm),
              if (snapshot.projects.isEmpty)
                const PulseCard(child: Padding(padding: EdgeInsets.all(PulseSpace.lg), child: Text('no projects yet.')))
              else
                ...snapshot.projects.where((project) => project.status == ProjectStatus.active).map((project) {
                  final projectTasks = snapshot.tasks.where((task) => task.projectId == project.id).toList();
                  final completed = projectTasks.where((task) => task.isCompleted).length;
                  final ratio = projectTasks.isEmpty ? 0.0 : completed / projectTasks.length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: PulseSpace.sm),
                    child: PulseCard(
                      child: Padding(
                        padding: const EdgeInsets.all(PulseSpace.lg),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Expanded(child: Text(project.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))), Text('$completed/${projectTasks.length}')]),
                          const SizedBox(height: PulseSpace.sm),
                          ClipRRect(borderRadius: BorderRadius.circular(PulseRadius.small), child: LinearProgressIndicator(value: ratio, minHeight: 6)),
                        ]),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => PulseCard(
        child: Padding(
          padding: const EdgeInsets.all(PulseSpace.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 22),
            const SizedBox(height: PulseSpace.xs),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}
