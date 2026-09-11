import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/di/providers.dart';
import '../../../models/task_model.dart';

enum TaskMutationStatus { idle, loading, success, failure }

class TaskMutationState {
  const TaskMutationState({
    this.status = TaskMutationStatus.idle,
    this.operation,
    this.error,
    this.task,
    this.completion,
    this.reopen,
    this.series,
  });

  final TaskMutationStatus status;
  final String? operation;
  final Object? error;
  final Task? task;
  final TaskCompletionResult? completion;
  final TaskReopenResult? reopen;
  final TaskSeries? series;

  bool get isLoading => status == TaskMutationStatus.loading;
  bool get canRetry => status == TaskMutationStatus.failure;

  TaskMutationState copyWith({
    TaskMutationStatus? status,
    String? operation,
    Object? error,
    bool clearError = false,
    Task? task,
    bool clearTask = false,
    TaskCompletionResult? completion,
    bool clearCompletion = false,
    TaskReopenResult? reopen,
    bool clearReopen = false,
    TaskSeries? series,
    bool clearSeries = false,
  }) {
    return TaskMutationState(
      status: status ?? this.status,
      operation: operation ?? this.operation,
      error: clearError ? null : error ?? this.error,
      task: clearTask ? null : task ?? this.task,
      completion: clearCompletion ? null : completion ?? this.completion,
      reopen: clearReopen ? null : reopen ?? this.reopen,
      series: clearSeries ? null : series ?? this.series,
    );
  }
}

final taskControllerProvider =
    NotifierProvider<TaskController, TaskMutationState>(TaskController.new);

class TaskController extends Notifier<TaskMutationState> {
  final Set<String> _inFlight = <String>{};
  int _generation = 0;
  Future<void> Function()? _retryAction;

  @override
  TaskMutationState build() => const TaskMutationState();

  Future<Task?> createTask({
    required String title,
    DateTime? dueDate,
    String? dueTime,
    String? projectId,
    String? milestoneId,
    int priority = 0,
  }) {
    return _run<Task>(
      operation: 'createTask',
      key: 'createTask',
      retry: () => createTask(
        title: title,
        dueDate: dueDate,
        dueTime: dueTime,
        projectId: projectId,
        milestoneId: milestoneId,
        priority: priority,
      ),
      action: () async {
        final uid = await _currentUid();
        return ref.read(taskRepositoryProvider).createTask(
              uid: uid,
              title: title,
              dueDate: dueDate,
              dueTime: dueTime,
              projectId: projectId,
              milestoneId: milestoneId,
              priority: priority,
            );
      },
      onSuccess: (task, generation) {
        if (generation == _generation) {
          state = state.copyWith(task: task, clearError: true);
        }
      },
    );
  }

  Future<Task?> updateTask({
    required String taskId,
    String? title,
    DateTime? dueDate,
    String? dueTime,
    String? projectId,
    String? milestoneId,
    int? priority,
  }) {
    return _run<Task>(
      operation: 'updateTask',
      key: 'updateTask:$taskId',
      retry: () => updateTask(
        taskId: taskId,
        title: title,
        dueDate: dueDate,
        dueTime: dueTime,
        projectId: projectId,
        milestoneId: milestoneId,
        priority: priority,
      ),
      action: () => ref.read(taskRepositoryProvider).updateTask(
            taskId: taskId,
            title: title,
            dueDate: dueDate,
            dueTime: dueTime,
            projectId: projectId,
            milestoneId: milestoneId,
            priority: priority,
          ),
      onSuccess: (task, generation) {
        if (generation == _generation) {
          state = state.copyWith(task: task, clearError: true);
        }
      },
    );
  }

  Future<bool> deleteTask({required String taskId}) async {
    final result = await _run<bool>(
      operation: 'deleteTask',
      key: 'deleteTask:$taskId',
      retry: () => deleteTask(taskId: taskId),
      action: () async {
        await ref.read(taskRepositoryProvider).deleteTask(taskId: taskId);
        return true;
      },
    );
    return result ?? false;
  }

  Future<TaskCompletionResult?> completeTask({required String taskId}) {
    return _run<TaskCompletionResult>(
      operation: 'completeTask',
      key: 'completeTask:$taskId',
      retry: () => completeTask(taskId: taskId),
      action: () => ref.read(taskRepositoryProvider).completeTask(taskId: taskId),
      onSuccess: (result, generation) {
        if (generation == _generation) {
          state = state.copyWith(completion: result, clearError: true);
        }
      },
    );
  }

  Future<TaskReopenResult?> reopenTask({required String taskId}) {
    return _run<TaskReopenResult>(
      operation: 'reopenTask',
      key: 'reopenTask:$taskId',
      retry: () => reopenTask(taskId: taskId),
      action: () => ref.read(taskRepositoryProvider).reopenTask(taskId: taskId),
      onSuccess: (result, generation) {
        if (generation == _generation) {
          state = state.copyWith(reopen: result, clearError: true);
        }
      },
    );
  }

  Future<TaskSeries?> createTaskSeries({
    required String title,
    String? description,
    String? projectId,
    String? milestoneId,
    int priority = 0,
    required TaskRecurrenceType recurrenceType,
    int recurrenceInterval = 1,
    String timezone = 'UTC',
    required DateTime startsAt,
    DateTime? untilAt,
    int? occurrenceCount,
  }) {
    return _run<TaskSeries>(
      operation: 'createTaskSeries',
      key: 'createTaskSeries',
      retry: () => createTaskSeries(
        title: title,
        description: description,
        projectId: projectId,
        milestoneId: milestoneId,
        priority: priority,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        timezone: timezone,
        startsAt: startsAt,
        untilAt: untilAt,
        occurrenceCount: occurrenceCount,
      ),
      action: () async {
        final uid = await _currentUid();
        return ref.read(taskRepositoryProvider).createTaskSeries(
              uid: uid,
              title: title,
              description: description,
              projectId: projectId,
              milestoneId: milestoneId,
              priority: priority,
              recurrenceType: recurrenceType,
              recurrenceInterval: recurrenceInterval,
              timezone: timezone,
              startsAt: startsAt,
              untilAt: untilAt,
              occurrenceCount: occurrenceCount,
            );
      },
      onSuccess: (series, generation) {
        if (generation == _generation) {
          state = state.copyWith(series: series, clearError: true);
        }
      },
    );
  }

  Future<TaskSeries?> updateTaskSeries({
    required String seriesId,
    String? title,
    String? description,
    String? projectId,
    String? milestoneId,
    int? priority,
    TaskRecurrenceType? recurrenceType,
    int? recurrenceInterval,
    String? timezone,
    DateTime? startsAt,
    DateTime? untilAt,
    int? occurrenceCount,
    bool? isActive,
  }) {
    return _run<TaskSeries>(
      operation: 'updateTaskSeries',
      key: 'updateTaskSeries:$seriesId',
      retry: () => updateTaskSeries(
        seriesId: seriesId,
        title: title,
        description: description,
        projectId: projectId,
        milestoneId: milestoneId,
        priority: priority,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        timezone: timezone,
        startsAt: startsAt,
        untilAt: untilAt,
        occurrenceCount: occurrenceCount,
        isActive: isActive,
      ),
      action: () => ref.read(taskRepositoryProvider).updateTaskSeries(
            seriesId: seriesId,
            title: title,
            description: description,
            projectId: projectId,
            milestoneId: milestoneId,
            priority: priority,
            recurrenceType: recurrenceType,
            recurrenceInterval: recurrenceInterval,
            timezone: timezone,
            startsAt: startsAt,
            untilAt: untilAt,
            occurrenceCount: occurrenceCount,
            isActive: isActive,
          ),
      onSuccess: (series, generation) {
        if (generation == _generation) {
          state = state.copyWith(series: series, clearError: true);
        }
      },
    );
  }

  Future<Task?> ensureTaskOccurrence({
    required String seriesId,
    required DateTime occurrenceKey,
  }) {
    final normalizedKey = occurrenceKey.toUtc().toIso8601String();
    return _run<Task>(
      operation: 'ensureTaskOccurrence',
      key: 'ensureTaskOccurrence:$seriesId:$normalizedKey',
      retry: () => ensureTaskOccurrence(
        seriesId: seriesId,
        occurrenceKey: occurrenceKey,
      ),
      action: () => ref.read(taskRepositoryProvider).ensureTaskOccurrence(
            seriesId: seriesId,
            occurrenceKey: occurrenceKey,
          ),
      onSuccess: (task, generation) {
        if (generation == _generation) {
          state = state.copyWith(task: task, clearError: true);
        }
      },
    );
  }

  Future<void> retry() async {
    final action = _retryAction;
    if (action == null) return;
    await action();
  }

  Future<String> _currentUid() async {
    final authState = await ref.read(authServiceProvider).authStateChanges.first;
    if (authState.status != AuthStatus.authenticated || authState.uid == null) {
      throw StateError('You must be signed in to manage tasks.');
    }
    return authState.uid!;
  }

  Future<T?> _run<T>({
    required String operation,
    required String key,
    required Future<T> Function() action,
    required Future<void> Function() retry,
    void Function(T value, int generation)? onSuccess,
  }) async {
    if (_inFlight.contains(key)) return null;

    _inFlight.add(key);
    final generation = ++_generation;
    _retryAction = retry;
    state = TaskMutationState(
      status: TaskMutationStatus.loading,
      operation: operation,
    );

    try {
      final value = await action();
      if (generation == _generation) {
        state = state.copyWith(status: TaskMutationStatus.success);
        onSuccess?.call(value, generation);
      }
      return value;
    } catch (error) {
      if (generation == _generation) {
        state = state.copyWith(
          status: TaskMutationStatus.failure,
          error: error,
        );
      }
      rethrow;
    } finally {
      _inFlight.remove(key);
    }
  }
}
