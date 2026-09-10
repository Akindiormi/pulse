import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/backend/trusted_challenge_backend.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../models/milestone_model.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';

Future<String> _currentUid(WidgetRef ref) async {
  final state = await ref.read(authServiceProvider).authStateChanges.first;
  if (state.status != AuthStatus.authenticated || state.uid == null) {
    throw const TrustedBackendException(TrustedBackendErrorCode.unauthenticated, 'Sign in to use projects.');
  }
  return state.uid!;
}

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});
  @override ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  late Future<List<Project>> _projects;
  @override void initState() { super.initState(); _reload(); }
  void _reload() { _projects = _load(); }
  Future<List<Project>> _load() async => ref.read(projectRepositoryProvider).getProjects(uid: await _currentUid(ref));

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Projects'), actions: [IconButton(onPressed: () => setState(_reload), icon: const Icon(Icons.refresh_rounded))]),
    floatingActionButton: FloatingActionButton(onPressed: () async { if (await _createProject()) setState(_reload); }, child: const Icon(Icons.add_rounded)),
    body: FutureBuilder<List<Project>>(
      future: _projects,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Could not load projects.\n${snapshot.error}', textAlign: TextAlign.center));
        final projects = snapshot.data ?? const <Project>[];
        if (projects.isEmpty) return const _EmptyProjects();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(PulseSpace.lg, PulseSpace.md, PulseSpace.lg, 96),
          itemCount: projects.length,
          separatorBuilder: (context, index) => const SizedBox(height: PulseSpace.md),
          itemBuilder: (context, index) {
            final project = projects[index];
            return Card(child: ListTile(
              contentPadding: const EdgeInsets.all(PulseSpace.md),
              leading: const CircleAvatar(backgroundColor: PulseColors.accentTint, child: Icon(Icons.folder_copy_rounded, color: PulseColors.accent)),
              title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: project.description?.isNotEmpty == true ? Text(project.description!, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async { await context.push('/projects/${project.id}'); if (mounted) setState(_reload); },
            ));
          },
        );
      },
    ),
  );

  Future<bool> _createProject() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (dialog) {
      return AlertDialog(
        title: const Text('New project'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Project name')),
          const SizedBox(height: PulseSpace.md),
          TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () async {
            if (name.text.trim().isEmpty) return;
            await ref.read(projectRepositoryProvider).createProject(uid: await _currentUid(ref), name: name.text, description: description.text);
            if (dialog.mounted) Navigator.pop(dialog, true);
          }, child: const Text('Create')),
        ],
      );
    });
    return result == true;
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(PulseSpace.xxxl), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.folder_open_rounded, size: 56, color: PulseColors.accent),
    const SizedBox(height: PulseSpace.xl),
    Text('Nothing here yet', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: PulseSpace.sm),
    const Text('Create a project and turn it into milestones and tasks.', textAlign: TextAlign.center),
  ])));
}

class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;
  @override ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  late Future<_ProjectData> _data;
  @override void initState() { super.initState(); _reload(); }
  void _reload() { _data = _load(); }
  Future<_ProjectData> _load() async {
    final uid = await _currentUid(ref);
    final project = await ref.read(projectRepositoryProvider).getProject(uid: uid, projectId: widget.projectId);
    if (project == null) throw Exception('Project not found');
    final milestones = await ref.read(milestoneRepositoryProvider).getMilestones(uid: uid, projectId: widget.projectId);
    final tasks = await ref.read(taskRepositoryProvider).getProjectTasks(uid: uid, projectId: widget.projectId);
    return _ProjectData(project, milestones, tasks);
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Project'), actions: [IconButton(onPressed: _deleteProject, icon: const Icon(Icons.delete_outline_rounded))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _addTask, icon: const Icon(Icons.add_task_rounded), label: const Text('Task')),
    body: FutureBuilder<_ProjectData>(future: _data, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
      final data = snapshot.data!;
      final projectProgress = _progress(data.tasks);
      return ListView(padding: const EdgeInsets.fromLTRB(PulseSpace.lg, PulseSpace.md, PulseSpace.lg, 120), children: [
        Text(data.project.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        if (data.project.description?.isNotEmpty == true) ...[const SizedBox(height: PulseSpace.sm), Text(data.project.description!)],
        const SizedBox(height: PulseSpace.xl),
        Card(child: Padding(padding: const EdgeInsets.all(PulseSpace.xl), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Progress', style: TextStyle(fontWeight: FontWeight.w700)), Text('${projectProgress.percent}%')]),
          const SizedBox(height: PulseSpace.md),
          LinearProgressIndicator(value: projectProgress.fraction, minHeight: 8, borderRadius: BorderRadius.circular(PulseRadius.pill)),
          const SizedBox(height: PulseSpace.sm), Text('${projectProgress.completed} of ${projectProgress.total} tasks completed'),
        ]))),
        const SizedBox(height: PulseSpace.xxl),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Milestones', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), IconButton(onPressed: _addMilestone, icon: const Icon(Icons.add_rounded))]),
        if (data.milestones.isEmpty) const Text('No milestones yet.'),
        ...data.milestones.map((milestone) => _MilestoneCard(milestone: milestone, tasks: data.tasks.where((task) => task.milestoneId == milestone.id).toList(), onRefresh: () => setState(_reload), ref: ref)),
        const SizedBox(height: PulseSpace.xxl),
        Text('Other tasks', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: PulseSpace.sm),
        ...data.tasks.where((task) => task.milestoneId == null).map((task) => _TaskTile(task: task, onRefresh: () => setState(_reload), ref: ref)),
        if (data.tasks.where((task) => task.milestoneId == null).isEmpty) const Text('Tasks without a milestone appear here.'),
      ]);
    }),
  );

  ProgressStats _progress(List<Task> tasks) => ProgressStats(completed: tasks.where((task) => task.isCompleted).length, total: tasks.length);

  Future<void> _addMilestone() async {
    final name = TextEditingController();
    final result = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(title: const Text('New milestone'), content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Milestone name')), actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; await ref.read(milestoneRepositoryProvider).createMilestone(uid: await _currentUid(ref), projectId: widget.projectId, name: name.text); if (dialog.mounted) Navigator.pop(dialog, true); }, child: const Text('Create'))]));
    if (result == true && mounted) setState(_reload);
  }

  Future<void> _addTask() async {
    final data = await _data;
    final title = TextEditingController();
    String? milestoneId;
    final result = await showDialog<bool>(context: context, builder: (dialog) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(title: const Text('New task'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Task')), const SizedBox(height: PulseSpace.md), DropdownButtonFormField<String?>(value: milestoneId, decoration: const InputDecoration(labelText: 'Milestone'), items: [const DropdownMenuItem<String?>(value: null, child: Text('Other tasks')), ...data.milestones.map((milestone) => DropdownMenuItem<String?>(value: milestone.id, child: Text(milestone.name)))], onChanged: (value) => setLocal(() => milestoneId = value))]), actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')), FilledButton(onPressed: () async { if (title.text.trim().isEmpty) return; await ref.read(taskRepositoryProvider).createTask(uid: await _currentUid(ref), title: title.text, dueDate: DateTime.now(), projectId: widget.projectId, milestoneId: milestoneId); if (dialog.mounted) Navigator.pop(dialog, true); }, child: const Text('Create'))])));
    if (result == true && mounted) setState(_reload);
  }

  Future<void> _deleteProject() async {
    final confirm = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(title: const Text('Delete project?'), content: const Text('This deletes the project, its milestones, and all project tasks.'), actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete'))]));
    if (confirm == true && mounted) { await ref.read(projectRepositoryProvider).deleteProject(projectId: widget.projectId); if (mounted) context.pop(); }
  }
}

class _ProjectData {
  const _ProjectData(this.project, this.milestones, this.tasks);
  final Project project;
  final List<Milestone> milestones;
  final List<Task> tasks;
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.milestone, required this.tasks, required this.onRefresh, required this.ref});
  final Milestone milestone;
  final List<Task> tasks;
  final VoidCallback onRefresh;
  final WidgetRef ref;
  @override Widget build(BuildContext context) {
    final progress = ProgressStats(completed: tasks.where((task) => task.isCompleted).length, total: tasks.length);
    return Card(margin: const EdgeInsets.only(bottom: PulseSpace.md), child: Padding(padding: const EdgeInsets.all(PulseSpace.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(milestone.name, style: const TextStyle(fontWeight: FontWeight.w700))), PopupMenuButton<String>(onSelected: (value) async { if (value == 'delete') { await ref.read(milestoneRepositoryProvider).deleteMilestone(milestoneId: milestone.id); onRefresh(); } }, itemBuilder: (context) => const [PopupMenuItem(value: 'delete', child: Text('Delete milestone'))])]),
      LinearProgressIndicator(value: progress.fraction, minHeight: 6, borderRadius: BorderRadius.circular(PulseRadius.pill)),
      const SizedBox(height: PulseSpace.xs), Text('${progress.percent}% · ${progress.completed}/${progress.total} tasks'),
      ...tasks.map((task) => _TaskTile(task: task, onRefresh: onRefresh, ref: ref)),
    ])));
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onRefresh, required this.ref});
  final Task task;
  final VoidCallback onRefresh;
  final WidgetRef ref;
  @override Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Checkbox(value: task.isCompleted, onChanged: task.isCompleted ? null : (_) async { await ref.read(taskRepositoryProvider).completeTask(taskId: task.id); onRefresh(); }),
    title: Text(task.title, style: TextStyle(decoration: task.isCompleted ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w600)),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: 'Focus on task',
        onPressed: () => context.push('/focus?taskId=${Uri.encodeComponent(task.id)}'),
        icon: const Icon(Icons.play_circle_outline_rounded),
      ),
      IconButton(onPressed: () async { await ref.read(taskRepositoryProvider).deleteTask(taskId: task.id); onRefresh(); }, icon: const Icon(Icons.delete_outline_rounded, size: 20)),
    ]),
  );
}
