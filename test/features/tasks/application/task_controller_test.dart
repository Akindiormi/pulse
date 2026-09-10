import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pulse/core/auth/auth_service.dart';
import 'package:pulse/core/database/repositories.dart';
import 'package:pulse/core/di/providers.dart';
import 'package:pulse/features/tasks/application/task_controller.dart';
import 'package:pulse/models/task_model.dart';

class _FakeAuthService implements AuthService {
  const _FakeAuthService(this.uid);
  final String? uid;

  @override
  Stream<AuthState> get authStateChanges => Stream.value(
        AuthState(
          status: uid == null || uid!.isEmpty ? AuthStatus.unauthenticated : AuthStatus.authenticated,
          uid: uid == null || uid!.isEmpty ? null : uid,
        ),
      );

  @override
  Future<AuthState> registerWithEmail({required String email, required String password}) => throw UnimplementedError();
  @override
  Future<AuthState> signInWithEmail({required String email, required String password}) => throw UnimplementedError();
  @override
  Future<AuthState> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<AuthState> signInWithApple() => throw UnimplementedError();
  @override
  Future<void> sendPasswordResetEmail({required String email}) => throw UnimplementedError();
  @override
  Future<void> signOut() => throw UnimplementedError();
  @override
  Future<void> deleteAccount() => throw UnimplementedError();
}

class _FakeTaskRepository implements TaskRepository {
  final List<Task> tasks = <Task>[];
  final Map<String, TaskSeries> series = <String, TaskSeries>{};
  final Set<String> rewarded = <String>{};
  int completeCalls = 0;
  Completer<TaskCompletionResult>? pendingCompletion;
  Object? nextError;
  int _taskNumber = 0;

  @override
  Future<List<Task>> getTasks({required String uid}) async => tasks.where((task) => task.userId == uid).toList();

  @override
  Future<List<Task>> getProjectTasks({required String uid, required String projectId}) async => tasks.where((task) => task.userId == uid && task.projectId == projectId).toList();

  @override
  Future<Task> createTask({required String uid, required String title, DateTime? dueDate, String? dueTime, String? projectId, String? milestoneId, int priority = 0}) async {
    final task = Task(id: 'task-${++_taskNumber}', userId: uid, title: title.trim(), dueDate: dueDate, dueTime: dueTime, projectId: projectId, milestoneId: milestoneId, priority: priority);
    tasks.add(task);
    return task;
  }

  @override
  Future<Task> updateTask({required String taskId, String? title, DateTime? dueDate, String? dueTime, String? projectId, String? milestoneId, int? priority}) async {
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) throw StateError('task not found');
    final updated = tasks[index].copyWith(title: title, dueDate: dueDate, dueTime: dueTime, projectId: projectId, milestoneId: milestoneId, priority: priority);
    tasks[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteTask({required String taskId}) async {
    tasks.removeWhere((task) => task.id == taskId);
  }

  @override
  Future<TaskCompletionResult> completeTask({required String taskId}) async {
    completeCalls++;
    if (pendingCompletion != null) return pendingCompletion!.future;
    if (nextError != null) {
      final error = nextError!;
      nextError = null;
      throw error;
    }
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) throw StateError('task not found');
    final current = tasks[index];
    if (current.isCompleted) return TaskCompletionResult(completed: false, alreadyCompleted: true, alreadyRewarded: true, taskId: taskId, firstCompletedAt: current.firstCompletedAt);
    final alreadyRewarded = rewarded.contains(taskId) || current.firstCompletedAt != null;
    final now = DateTime.utc(2026, 9, 10, 12);
    tasks[index] = current.copyWith(status: TaskStatus.completed, completedAt: now, firstCompletedAt: current.firstCompletedAt ?? now);
    if (!alreadyRewarded) rewarded.add(taskId);
    return TaskCompletionResult(completed: true, alreadyCompleted: false, alreadyRewarded: alreadyRewarded, taskId: taskId, xpAwarded: alreadyRewarded ? 0 : 10, firstCompletedAt: tasks[index].firstCompletedAt, completedAt: now);
  }

  @override
  Future<TaskReopenResult> reopenTask({required String taskId}) async {
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) throw StateError('task not found');
    final current = tasks[index];
    if (!current.isCompleted) return TaskReopenResult(reopened: false, alreadyOpen: true, taskId: taskId, status: current.status, firstCompletedAt: current.firstCompletedAt);
    tasks[index] = current.copyWith(status: TaskStatus.todo, clearCompletedAt: true);
    return TaskReopenResult(reopened: true, alreadyOpen: false, taskId: taskId, status: TaskStatus.todo, firstCompletedAt: current.firstCompletedAt);
  }

  @override
  Future<TaskSeries> createTaskSeries({required String uid, required String title, String? description, String? projectId, String? milestoneId, int priority = 0, required TaskRecurrenceType recurrenceType, int recurrenceInterval = 1, String timezone = 'UTC', required DateTime startsAt, DateTime? untilAt, int? occurrenceCount}) async {
    final item = TaskSeries(id: 'series-1', userId: uid, title: title, description: description, projectId: projectId, milestoneId: milestoneId, priority: priority, recurrenceType: recurrenceType, recurrenceInterval: recurrenceInterval, timezone: timezone, startsAt: startsAt, untilAt: untilAt, occurrenceCount: occurrenceCount);
    series[item.id] = item;
    return item;
  }

  @override
  Future<TaskSeries> updateTaskSeries({required String seriesId, String? title, String? description, String? projectId, String? milestoneId, int? priority, TaskRecurrenceType? recurrenceType, int? recurrenceInterval, String? timezone, DateTime? startsAt, DateTime? untilAt, int? occurrenceCount, bool? isActive}) async {
    final current = series[seriesId];
    if (current == null) throw StateError('series not found');
    final updated = TaskSeries(id: current.id, userId: current.userId, title: title ?? current.title, description: description ?? current.description, projectId: projectId ?? current.projectId, milestoneId: milestoneId ?? current.milestoneId, priority: priority ?? current.priority, recurrenceType: recurrenceType ?? current.recurrenceType, recurrenceInterval: recurrenceInterval ?? current.recurrenceInterval, timezone: timezone ?? current.timezone, startsAt: startsAt ?? current.startsAt, untilAt: untilAt ?? current.untilAt, occurrenceCount: occurrenceCount ?? current.occurrenceCount, isActive: isActive ?? current.isActive, createdAt: current.createdAt, updatedAt: current.updatedAt);
    series[seriesId] = updated;
    return updated;
  }

  @override
  Future<Task> ensureTaskOccurrence({required String seriesId, required DateTime occurrenceKey}) async {
    final existing = tasks.where((task) => task.taskSeriesId == seriesId && task.occurrenceKey == occurrenceKey).toList();
    if (existing.isNotEmpty) return existing.first;
    final item = Task(id: 'occurrence-${++_taskNumber}', userId: 'user-1', title: series[seriesId]?.title ?? 'recurring task', taskSeriesId: seriesId, occurrenceKey: occurrenceKey);
    tasks.add(item);
    return item;
  }
}

ProviderContainer _container(_FakeTaskRepository repository, {String uid = 'user-1'}) {
  return ProviderContainer(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      authServiceProvider.overrideWithValue(_FakeAuthService(uid)),
    ],
  );
}

void main() {
  test('normal lifecycle delegates completion and reopen without client rewards', () async {
    final repository = _FakeTaskRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);

    final task = await controller.createTask(title: 'finish work', projectId: 'project-1', milestoneId: 'milestone-1', priority: 2);
    expect(task, isNotNull);
    expect(controller.state.status, TaskMutationStatus.success);

    final first = await controller.completeTask(taskId: task!.id);
    expect(first?.xpAwarded, 10);
    expect(first?.alreadyRewarded, isFalse);
    expect(repository.rewarded, <String>{task.id});

    final reopened = await controller.reopenTask(taskId: task.id);
    expect(reopened?.reopened, isTrue);
    expect(reopened?.firstCompletedAt, first?.firstCompletedAt);

    final second = await controller.completeTask(taskId: task.id);
    expect(second?.completed, isTrue);
    expect(second?.alreadyRewarded, isTrue);
    expect(second?.xpAwarded, 0);
    expect(repository.rewarded, <String>{task.id});
    expect(controller.state.completion?.alreadyRewarded, isTrue);
  });

  test('duplicate completion submission is suppressed while request is in flight', () async {
    final repository = _FakeTaskRepository()..tasks.add(const Task(id: 'task-1', userId: 'user-1', title: 'one'));
    final pending = Completer<TaskCompletionResult>();
    repository.pendingCompletion = pending;
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);

    final firstFuture = controller.completeTask(taskId: 'task-1');
    await Future<void>.delayed(Duration.zero);
    final duplicate = await controller.completeTask(taskId: 'task-1');
    expect(duplicate, isNull);
    expect(repository.completeCalls, 1);

    pending.complete(const TaskCompletionResult(completed: true, alreadyCompleted: false, alreadyRewarded: false, taskId: 'task-1', xpAwarded: 10));
    final first = await firstFuture;
    expect(first?.xpAwarded, 10);
    expect(controller.state.status, TaskMutationStatus.success);
  });

  test('recurring series creation, update and occurrence identity flow through controller', () async {
    final repository = _FakeTaskRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);

    final series = await controller.createTaskSeries(title: 'gym', recurrenceType: TaskRecurrenceType.weekly, recurrenceInterval: 1, timezone: 'Africa/Lagos', startsAt: DateTime.utc(2026, 9, 14, 17), projectId: 'project-1', milestoneId: 'milestone-1');
    expect(series?.projectId, 'project-1');
    expect(series?.milestoneId, 'milestone-1');

    final updated = await controller.updateTaskSeries(seriesId: series!.id, priority: 2, isActive: true);
    expect(updated?.priority, 2);

    final key = DateTime.utc(2026, 9, 14, 17);
    final first = await controller.ensureTaskOccurrence(seriesId: series.id, occurrenceKey: key);
    final duplicate = await controller.ensureTaskOccurrence(seriesId: series.id, occurrenceKey: key);
    final next = await controller.ensureTaskOccurrence(seriesId: series.id, occurrenceKey: key.add(const Duration(days: 7)));

    expect(duplicate?.id, first?.id);
    expect(next?.id, isNot(first?.id));
    expect(first?.taskSeriesId, series.id);
    expect(next?.taskSeriesId, series.id);
  });

  test('failure is exposed and retry re-runs the same repository mutation', () async {
    final repository = _FakeTaskRepository()..nextError = StateError('temporary failure');
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);

    await expectLater(controller.createTask(title: 'retry me'), throwsA(isA<StateError>()));
    expect(controller.state.status, TaskMutationStatus.failure);
    expect(controller.state.canRetry, isTrue);

    await controller.retry();
    expect(controller.state.status, TaskMutationStatus.success);
    expect(controller.state.task?.title, 'retry me');
  });

  test('stale completion cannot overwrite a newer mutation state', () async {
    final repository = _FakeTaskRepository()..tasks.add(const Task(id: 'task-1', userId: 'user-1', title: 'one'));
    final pending = Completer<TaskCompletionResult>();
    repository.pendingCompletion = pending;
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);

    final completion = controller.completeTask(taskId: 'task-1');
    await Future<void>.delayed(Duration.zero);
    final created = await controller.createTask(title: 'new task');
    expect(created?.title, 'new task');
    expect(controller.state.task?.title, 'new task');

    pending.complete(const TaskCompletionResult(completed: true, alreadyCompleted: false, alreadyRewarded: false, taskId: 'task-1', xpAwarded: 10));
    await completion;
    expect(controller.state.task?.title, 'new task');
  });

  test('unauthenticated series creation fails through controller state', () async {
    final repository = _FakeTaskRepository();
    final container = _container(repository, uid: '');
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);

    await expectLater(controller.createTaskSeries(title: 'gym', recurrenceType: TaskRecurrenceType.daily, startsAt: DateTime.utc(2026, 9, 10)), throwsA(isA<StateError>()));
    expect(controller.state.status, TaskMutationStatus.failure);
  });
}
