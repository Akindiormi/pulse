import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/database/repositories.dart';
import 'package:pulse/models/task_model.dart';

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(this._tasks);
  final List<Task> _tasks;
  int rewardCount = 0;
  final Set<String> _rewardedTaskIds = <String>{};

  @override
  Future<List<Task>> getTasks({required String uid}) async => _tasks.where((task) => task.userId == uid).toList(growable: false);

  @override
  Future<List<Task>> getProjectTasks({required String uid, required String projectId}) async => _tasks.where((task) => task.userId == uid && task.projectId == projectId).toList(growable: false);

  @override
  Future<Task> createTask({required String uid, required String title, DateTime? dueDate, String? dueTime, String? projectId, String? milestoneId, int priority = 0}) async {
    final task = Task(id: 'task-${_tasks.length + 1}', userId: uid, title: title.trim(), dueDate: dueDate, dueTime: dueTime, projectId: projectId, milestoneId: milestoneId, priority: priority);
    _tasks.add(task);
    return task;
  }

  @override
  Future<Task> updateTask({required String taskId, String? title, DateTime? dueDate, String? dueTime, String? projectId, String? milestoneId, int? priority}) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) throw StateError('Task not found');
    final current = _tasks[index];
    final updated = current.copyWith(title: title, dueDate: dueDate, dueTime: dueTime, projectId: projectId, milestoneId: milestoneId, priority: priority);
    _tasks[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteTask({required String taskId}) async => _tasks.removeWhere((task) => task.id == taskId);

  @override
  Future<TaskCompletionResult> completeTask({required String taskId}) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) throw StateError('Task not found');
    final current = _tasks[index];
    if (current.status == TaskStatus.completed) return const TaskCompletionResult(completed: false, alreadyCompleted: true, alreadyRewarded: true);
    final alreadyRewarded = _rewardedTaskIds.contains(taskId) || current.firstCompletedAt != null;
    final now = DateTime.utc(2026, 9, 10, 12);
    _tasks[index] = current.copyWith(status: TaskStatus.completed, firstCompletedAt: current.firstCompletedAt ?? now, completedAt: now);
    if (!alreadyRewarded) {
      _rewardedTaskIds.add(taskId);
      rewardCount++;
    }
    return TaskCompletionResult(completed: true, alreadyCompleted: false, alreadyRewarded: alreadyRewarded, taskId: taskId, xpAwarded: alreadyRewarded ? 0 : 10, firstCompletedAt: _tasks[index].firstCompletedAt, completedAt: now);
  }

  @override
  Future<TaskReopenResult> reopenTask({required String taskId}) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) throw StateError('Task not found');
    final current = _tasks[index];
    if (current.status != TaskStatus.completed) return TaskReopenResult(reopened: false, alreadyOpen: true, taskId: taskId, status: current.status, firstCompletedAt: current.firstCompletedAt);
    _tasks[index] = current.copyWith(status: TaskStatus.todo, clearCompletedAt: true);
    return TaskReopenResult(reopened: true, alreadyOpen: false, taskId: taskId, status: TaskStatus.todo, firstCompletedAt: current.firstCompletedAt);
  }

  @override
  Future<TaskSeries> createTaskSeries({required String uid, required String title, String? description, String? projectId, String? milestoneId, int priority = 0, required TaskRecurrenceType recurrenceType, int recurrenceInterval = 1, String timezone = 'UTC', required DateTime startsAt, DateTime? untilAt, int? occurrenceCount}) async => TaskSeries(id: 'series-1', userId: uid, title: title.trim(), description: description, projectId: projectId, milestoneId: milestoneId, priority: priority, recurrenceType: recurrenceType, recurrenceInterval: recurrenceInterval, timezone: timezone, startsAt: startsAt, untilAt: untilAt, occurrenceCount: occurrenceCount);

  @override
  Future<TaskSeries> updateTaskSeries({required String seriesId, String? title, String? description, String? projectId, String? milestoneId, int? priority, TaskRecurrenceType? recurrenceType, int? recurrenceInterval, String? timezone, DateTime? startsAt, DateTime? untilAt, int? occurrenceCount, bool? isActive}) async => throw UnimplementedError();

  @override
  Future<Task> ensureTaskOccurrence({required String seriesId, required DateTime occurrenceKey}) async {
    final existing = _tasks.where((task) => task.taskSeriesId == seriesId && task.occurrenceKey == occurrenceKey).firstOrNull;
    if (existing != null) return existing;
    final task = Task(id: 'occurrence-${_tasks.length + 1}', userId: 'user-1', title: 'recurring task', taskSeriesId: seriesId, occurrenceKey: occurrenceKey);
    _tasks.add(task);
    return task;
  }
}

void main() {
  test('normal task lifecycle preserves historical reward identity', () async {
    final repository = FakeTaskRepository(<Task>[]);
    final task = await repository.createTask(uid: 'user-1', title: '  finish work  ', dueDate: DateTime(2026, 9, 10), dueTime: '18:00:00', projectId: 'project-1', milestoneId: 'milestone-1', priority: 2);

    expect(task.title, 'finish work');
    expect(task.dueDate, DateTime(2026, 9, 10));
    expect(task.priority, 2);
    expect(task.projectId, 'project-1');
    expect(task.milestoneId, 'milestone-1');

    final edited = await repository.updateTask(taskId: task.id, title: 'finish work today', priority: 3);
    expect(edited.title, 'finish work today');
    expect(edited.priority, 3);

    final first = await repository.completeTask(taskId: task.id);
    expect(first.xpAwarded, 10);
    expect(first.alreadyRewarded, isFalse);
    expect(first.firstCompletedAt, isNotNull);
    expect(repository.rewardCount, 1);

    final reopened = await repository.reopenTask(taskId: task.id);
    expect(reopened.reopened, isTrue);
    expect(reopened.firstCompletedAt, first.firstCompletedAt);

    final second = await repository.completeTask(taskId: task.id);
    expect(second.completed, isTrue);
    expect(second.alreadyRewarded, isTrue);
    expect(second.xpAwarded, 0);
    expect(second.firstCompletedAt, first.firstCompletedAt);
    expect(repository.rewardCount, 1);
  });

  test('occurrence generation returns the same identity for duplicates', () async {
    final repository = FakeTaskRepository(<Task>[]);
    final key = DateTime.parse('2026-09-14T08:00:00Z');

    final first = await repository.ensureTaskOccurrence(seriesId: 'series-1', occurrenceKey: key);
    final duplicate = await repository.ensureTaskOccurrence(seriesId: 'series-1', occurrenceKey: key);
    final next = await repository.ensureTaskOccurrence(seriesId: 'series-1', occurrenceKey: key.add(const Duration(days: 1)));

    expect(duplicate.id, first.id);
    expect(duplicate.occurrenceKey, first.occurrenceKey);
    expect(next.id, isNot(first.id));
    expect(next.occurrenceKey, isNot(first.occurrenceKey));
  });

  test('task listing remains isolated by user', () async {
    final repository = FakeTaskRepository(<Task>[
      const Task(id: 'a', userId: 'user-a', title: 'A'),
      const Task(id: 'b', userId: 'user-b', title: 'B'),
    ]);

    final tasks = await repository.getTasks(uid: 'user-a');
    expect(tasks.map((task) => task.id), <String>['a']);
  });

  test('delete removes only the requested task', () async {
    final repository = FakeTaskRepository(<Task>[
      const Task(id: 'a', userId: 'user-a', title: 'A'),
      const Task(id: 'b', userId: 'user-a', title: 'B'),
    ]);

    await repository.deleteTask(taskId: 'a');
    expect((await repository.getTasks(uid: 'user-a')).map((task) => task.id), <String>['b']);
  });
}
