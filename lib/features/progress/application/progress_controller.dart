import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../models/focus_session_model.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';

class ProgressSnapshot {
  const ProgressSnapshot({required this.user, required this.tasks, required this.projects, required this.focusSessions});

  final UserModel user;
  final List<Task> tasks;
  final List<Project> projects;
  final List<FocusSession> focusSessions;

  int get completedTasks => tasks.where((task) => task.isCompleted).length;
  int get activeProjects => projects.where((project) => project.status == ProjectStatus.active).length;
  int get totalFocusSeconds => focusSessions.fold<int>(0, (sum, session) => sum + session.activeDurationSeconds);
  int get completedFocusSessions => focusSessions.where((session) => session.status == FocusSessionStatus.completed).length;
}

final progressControllerProvider = AsyncNotifierProvider<ProgressController, ProgressSnapshot>(ProgressController.new);

class ProgressController extends AsyncNotifier<ProgressSnapshot> {
  @override
  Future<ProgressSnapshot> build() async {
    final user = ref.read(supabaseProvider).auth.currentUser;
    if (user == null) throw StateError('You must be signed in to view progress.');

    final results = await Future.wait<dynamic>([
      ref.read(userRepositoryProvider).getUserModel(user.id),
      ref.read(taskRepositoryProvider).getTasks(uid: user.id),
      ref.read(projectRepositoryProvider).getProjects(uid: user.id),
      ref.read(focusRepositoryProvider).getSessionHistory(limit: 100),
    ]);

    final profile = results[0] as UserModel?;
    if (profile == null) throw StateError('Your profile could not be loaded.');

    return ProgressSnapshot(
      user: profile,
      tasks: results[1] as List<Task>,
      projects: results[2] as List<Project>,
      focusSessions: results[3] as List<FocusSession>,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => build());
  }
}
