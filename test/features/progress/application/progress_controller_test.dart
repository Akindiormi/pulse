import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/features/progress/application/progress_controller.dart';
import 'package:pulse/models/focus_session_model.dart';
import 'package:pulse/models/project_model.dart';
import 'package:pulse/models/task_model.dart';
import 'package:pulse/models/user_model.dart';

void main() {
  final now = DateTime.utc(2026, 9, 10, 1);

  test('aggregates progress from existing source models without cached state', () {
    final snapshot = ProgressSnapshot(
      user: const UserModel(uid: 'u1', currentStreak: 4, longestStreak: 9, xp: 240, level: 3),
      tasks: const [
        Task(id: 't1', userId: 'u1', title: 'done', status: TaskStatus.completed, projectId: 'p1'),
        Task(id: 't2', userId: 'u1', title: 'open', status: TaskStatus.todo, projectId: 'p1'),
      ],
      projects: const [
        Project(id: 'p1', userId: 'u1', name: 'active', status: ProjectStatus.active),
        Project(id: 'p2', userId: 'u1', name: 'completed', status: ProjectStatus.completed),
      ],
      focusSessions: [
        FocusSession(id: 'f1', userId: 'u1', status: FocusSessionStatus.completed, plannedDurationSeconds: 1800, startedAt: now, activeDurationSeconds: 1200),
        FocusSession(id: 'f2', userId: 'u1', status: FocusSessionStatus.cancelled, plannedDurationSeconds: 1800, startedAt: now, activeDurationSeconds: 300),
      ],
    );

    expect(snapshot.completedTasks, 1);
    expect(snapshot.activeProjects, 1);
    expect(snapshot.totalFocusSeconds, 1500);
    expect(snapshot.completedFocusSessions, 1);
    expect(snapshot.user.currentStreak, 4);
    expect(snapshot.user.xp, 240);
    expect(snapshot.user.level, 3);
  });
}
