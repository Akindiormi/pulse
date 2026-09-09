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

Future<String?> _uid(WidgetRef ref) async {
  final state = await ref.read(authServiceProvider).authStateChanges.first;
  if (state.status != AuthStatus.authenticated || state.uid == null) {
    throw const TrustedBackendException(TrustedBackendErrorCode.unauthenticated, 'Sign in to use projects.');
  }
  return state.uid;
}

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});
  @override State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  late Future<List<Project>> _future;
  @override void initState() { super.initState(); _future = _load(); }
  Future<List<Project>> _load() async { final uid = await _uid(ref); return ref.read(projectRepositoryProvider).getProjects(uid: uid!); }
  void _refresh() => setState(() => _future = _load());

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Projects'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))]),
    floatingActionButton: FloatingActionButton(onPressed: () async { if (await _projectDialog(context) == true) _refresh(); }, child: const Icon(Icons.add_rounded)),
    body: FutureBuilder<List<Project>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(PulseSpace.xxl), child: Text('Could not load projects.\n${snapshot.error}', textAlign: TextAlign.center)));
        final projects = snapshot.data ?? const <Project>[];
        if (projects.isEmpty) return const _EmptyProjects();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(PulseSpace.lg, PulseSpace.md, PulseSpace.lg, 96),
          itemCount: projects.length,
          separatorBuilder: (_, __) => const SizedBox(height: PulseSpace.md),
          itemBuilder: (context, index) => _ProjectCard(project: projects[index], onTap: () async { await context.push('/projects/${projects[index].id}'); if (mounted) _refresh(); }),
        );
      },
    ),
  );

  Future<bool?> _projectDialog(BuildContext context, {Project? project}) async {
    final name = TextEditingController(text: project?.name);
    final description = TextEditingController(text: project?.description);
    return showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(project == null ? 'New project' : 'Edit project'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Project name')),
        const SizedBox(height: PulseSpace.md),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; try { final uid = await _uid(ref); if (project == null) { await ref.read(projectRepositoryProvider).createProject(uid: uid!, name: name.text, description: description.text); } else { await ref.read(projectRepositoryProvider).updateProject(projectId: project.id, name: name.text, description: description.text); } if (context.mounted) Navigator.pop(context, true); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save project: $e'))); } }, child: const Text('Save'))],
    ));
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project, required this.onTap});
  final Project project; final VoidCallback onTap;
  @override Widget build(BuildContext context, WidgetRef ref) => Card(
    child: InkWell(borderRadius: BorderRadius.circular(PulseRadius.large), onTap: onTap, child: Padding(padding: const EdgeInsets.all(PulseSpace.xl), child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: PulseColors.accentTint, borderRadius: BorderRadius.circular(PulseRadius.medium)), child: const Icon(Icons.folder_copy_rounded, color: PulseColors.accent)),
      const SizedBox(width: PulseSpace.lg),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(project.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), if (project.description?.isNotEmpty == true) ...[const SizedBox(height: 4), Text(project.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)] ])),
      const Icon(Icons.chevron_right_rounded),
    ]))),
  );
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(PulseSpace.xxxl), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 72, height: 72, decoration: BoxDecoration(color: PulseColors.accentTint, borderRadius: BorderRadius.circular(PulseRadius.large)), child: const Icon(Icons.folder_open_rounded, size: 34, color: PulseColors.accent)),
    const SizedBox(height: PulseSpace.xl),
    Text('Nothing here yet', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: PulseSpace.sm),
    const Text('Create a project and break the work into milestones and tasks.', textAlign: TextAlign.center),
  ]));
}

class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;
  @override State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  late Future<_ProjectDetailData> _future;
  @override void initState() { super.initState(); _future = _load(); }
  Future<_ProjectDetailData> _load() async { final uid = await _uid(ref); final project = await ref.read(projectRepositoryProvider).getProject(uid: uid!, projectId: widget.projectId); if (project == null) throw Exception('Project not found'); final milestones = await ref.read(milestoneRepositoryProvider).getMilestones(uid: uid, projectId: widget.projectId); final tasks = await ref.read(taskRepositoryProvider).getProjectTasks(uid: uid, projectId: widget.projectId); return _ProjectDetailData(project, milestones, tasks); }
  void _refresh() => setState(() => _future = _load());

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Project'), actions: [IconButton(onPressed: () => _editProject(), icon: const Icon(Icons.edit_rounded)), IconButton(onPressed: () => _deleteProject(), icon: const Icon(Icons.delete_outline_rounded))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: () async { final data = await _future; if (await _taskDialog(data) == true) _refresh(); }, icon: const Icon(Icons.add_task_rounded), label: const Text('Task')),
    body: FutureBuilder<_ProjectDetailData>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
      final data = snapshot.data!;
      final completed = data.tasks.where((t) => t.isCompleted).length;
      final progress = ProgressStats(completed: completed, total: data.tasks.length);
      final byMilestone = <String, List<Task>>{};
      for (final task in data.tasks) { if (task.milestoneId != null) (byMilestone[task.milestoneId!] ??= []).add(task); }
      final other = data.tasks.where((task) => task.milestoneId == null).toList(growable: false);
      return ListView(padding: const EdgeInsets.fromLTRB(PulseSpace.lg, PulseSpace.md, PulseSpace.lg, 120), children: [
        Text(data.project.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        if (data.project.description?.isNotEmpty == true) ...[const SizedBox(height: PulseSpace.sm), Text(data.project.description!)],
        const SizedBox(height: PulseSpace.xl),
        Card(child: Padding(padding: const EdgeInsets.all(PulseSpace.xl), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Progress', style: TextStyle(fontWeight: FontWeight.w700)), Text('${progress.percent}%', style: const TextStyle(fontWeight: FontWeight.w800))]),
          const SizedBox(height: PulseSpace.md), LinearProgressIndicator(value: progress.fraction, minHeight: 8, borderRadius: BorderRadius.circular(PulseRadius.pill)),
          const SizedBox(height: PulseSpace.sm), Text('${progress.completed} of ${progress.total} tasks completed'),
        ]))),
        const SizedBox(height: PulseSpace.xxl),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Milestones', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), IconButton(onPressed: () async { if (await _milestoneDialog() == true) _refresh(); }, icon: const Icon(Icons.add_rounded))]),
        const SizedBox(height: PulseSpace.sm),
        if (data.milestones.isEmpty) const Text('No milestones yet. Add one when a project has a clear checkpoint.'),
        ...data.milestones.map((milestone) => _MilestoneSection(milestone: milestone, tasks: byMilestone[milestone.id] ?? const <Task>[], onRefresh: _refresh, ref: ref)),
        const SizedBox(height: PulseSpace.xxl),
        Text('Other tasks', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: PulseSpace.sm),
        if (other.isEmpty) const Text('Tasks without a milestone will appear here.'),
        ...other.map((task) => _TaskTile(task: task, onRefresh: _refresh, ref: ref)),
      ]);
    }),
  );

  Future<void> _editProject() async {
    final data = await _future; final name = TextEditingController(text: data.project.name); final description = TextEditingController(text: data.project.description);
    if (!mounted) return;
    await showDialog(context: context, builder: (dialog) => AlertDialog(title: const Text('Edit project'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Project name')), const SizedBox(height: 12), TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')), FilledButton(onPressed: () async { await ref.read(projectRepositoryProvider).updateProject(projectId: widget.projectId, name: name.text, description: description.text); if (dialog.mounted) Navigator.pop(dialog); _refresh(); }, child: const Text('Save'))]));
  }

  Future<void> _deleteProject() async {
    final ok = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(title: const Text('Delete project?'), content: const Text('This deletes the project, its milestones, and all tasks inside it.'), actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete'))]));
    if (ok == true && mounted) { await ref.read(projectRepositoryProvider).deleteProject(projectId: widget.projectId); if (mounted) context.pop(); }
  }

  Future<bool?> _milestoneDialog() async {
    final name = TextEditingController(); final description = TextEditingController();
    return showDialog<bool>(context: context, builder: (dialog) => AlertDialog(title: const Text('New milestone'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Milestone name')), const SizedBox(height: 12), TextField(controller: description, decoration: const InputDecoration(labelText: 'Description'))]), actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; final uid = await _uid(ref); await ref.read(milestoneRepositoryProvider).createMilestone(uid: uid!, projectId: widget.projectId, name: name.text, description: description.text); if (dialog.mounted) Navigator.pop(dialog, true); }, child: const Text('Create'))]));
  }

  Future<bool?> _taskDialog(_ProjectDetailData data) async {
    final title = TextEditingController(); String? milestoneId;
    return showDialog<bool>(context: context, builder: (dialog) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(title: const Text('New task'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Task')), const SizedBox(height: 12), DropdownButtonFormField<String?>(value: milestoneId, decoration: const InputDecoration(labelText: 'Milestone'), items: [const DropdownMenuItem<String?>(value: null, child: Text('Other tasks')), ...data.milestones.map((m) => DropdownMenuItem<String?>(value: m.id, child: Text(m.name)))], onChanged: (value) => setLocal(() => milestoneId = value))]), actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')), FilledButton(onPressed: () async { if (title.text.trim().isEmpty) return; final uid = await _uid(ref); await ref.read(taskRepositoryProvider).createTask(uid: uid!, title: title.text, dueDate: DateTime.now(), projectId: widget.projectId, milestoneId: milestoneId); if (dialog.mounted) Navigator.pop(dialog, true); }, child: const Text('Create'))])));
  }
}

class _ProjectDetailData {
  const _ProjectDetailData(this.project, this.milestones, this.tasks);
  final Project project; final List<Milestone> milestones; final List<Task> tasks;
}

class _MilestoneSection extends StatelessWidget {
  const _MilestoneSection({required this.milestone, required this.tasks, required this.onRefresh, required this.ref});
  final Milestone milestone; final List<Task> tasks; final VoidCallback onRefresh; final WidgetRef ref;
  @override Widget build(BuildContext context) { final p = ProgressStats(completed: tasks.where((t) => t.isCompleted).length, total: tasks.length); return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(PulseSpace.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(milestone.name, style: const TextStyle(fontWeight: FontWeight.w700))), PopupMenuButton<String>(onSelected: (value) async { if (value == 'delete') { await ref.read(milestoneRepositoryProvider).deleteMilestone(milestoneId: milestone.id); onRefresh(); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete milestone'))])]), const SizedBox(height: 8), LinearProgressIndicator(value: p.fraction, minHeight: 6, borderRadius: BorderRadius.circular(PulseRadius.pill)), const SizedBox(height: 6), Text('${p.percent}% · ${p.completed}/${p.total} tasks'), ...tasks.map((task) => _TaskTile(task: task, onRefresh: onRefresh, ref: ref))])); }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onRefresh, required this.ref});
  final Task task; final VoidCallback onRefresh; final WidgetRef ref;
  @override Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, leading: Checkbox(value: task.isCompleted, onChanged: task.isCompleted ? null : (_) async { await ref.read(taskRepositoryProvider).completeTask(taskId: task.id); onRefresh(); }), title: Text(task.title, style: TextStyle(decoration: task.isCompleted ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w600)), subtitle: task.dueDate == null ? null : Text('Due ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}'), trailing: IconButton(onPressed: () async { await ref.read(taskRepositoryProvider).deleteTask(taskId: task.id); onRefresh(); }, icon: const Icon(Icons.delete_outline_rounded, size: 20)));
}
