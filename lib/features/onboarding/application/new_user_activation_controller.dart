import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';

/// Persists the small amount of state needed to resume the first-use journey.
/// Real projects/tasks/focus sessions remain in Supabase; these values only
/// tell startup which activation step should be restored.
enum ActivationStep { personal, priority, work, focus, firstWin, complete }

class NewUserActivationState {
  const NewUserActivationState({this.active = false, this.step = ActivationStep.personal, this.area, this.priority, this.projectId, this.taskId});
  final bool active;
  final ActivationStep step;
  final String? area;
  final String? priority;
  final String? projectId;
  final String? taskId;

  NewUserActivationState copyWith({bool? active, ActivationStep? step, String? area, String? priority, String? projectId, String? taskId}) => NewUserActivationState(
        active: active ?? this.active,
        step: step ?? this.step,
        area: area ?? this.area,
        priority: priority ?? this.priority,
        projectId: projectId ?? this.projectId,
        taskId: taskId ?? this.taskId,
      );
}

class NewUserActivationController extends AsyncNotifier<NewUserActivationState> {
  static const _activeKey = 'pulse.activation.active';
  static const _stepKey = 'pulse.activation.step';
  static const _areaKey = 'pulse.activation.area';
  static const _priorityKey = 'pulse.activation.priority';
  static const _projectKey = 'pulse.activation.project_id';
  static const _taskKey = 'pulse.activation.task_id';

  SharedPreferencesAsync get _prefs => SharedPreferencesAsync();

  @override
  Future<NewUserActivationState> build() async {
    final active = await _prefs.getBool(_activeKey) ?? false;
    final stepIndex = await _prefs.getInt(_stepKey) ?? 0;
    final step = ActivationStep.values[stepIndex.clamp(0, ActivationStep.values.length - 1)];
    return NewUserActivationState(
      active: active,
      step: step,
      area: await _prefs.getString(_areaKey),
      priority: await _prefs.getString(_priorityKey),
      projectId: await _prefs.getString(_projectKey),
      taskId: await _prefs.getString(_taskKey),
    );
  }

  Future<void> begin() async {
    await _prefs.setBool(_activeKey, true);
    await _prefs.setInt(_stepKey, ActivationStep.personal.index);
    state = const AsyncData(NewUserActivationState(active: true));
  }

  Future<void> savePersonal({required String displayName, required String area}) async {
    final current = state.valueOrNull ?? const NewUserActivationState(active: true);
    final auth = await ref.read(authServiceProvider).authStateChanges.first;
    if (auth.uid == null) throw StateError('Your session has expired. Please sign in again.');
    await ref.read(userRepositoryProvider).createOrUpdateUser(uid: auth.uid!, displayName: displayName.trim());
    await _prefs.setString(_areaKey, area);
    await _setStep(ActivationStep.priority);
    state = AsyncData(current.copyWith(active: true, step: ActivationStep.priority, area: area));
  }

  Future<void> savePriority(String priority) async {
    final value = priority.trim();
    if (value.isEmpty) throw ArgumentError('Tell Pulse what matters right now.');
    await _prefs.setString(_priorityKey, value);
    await _setStep(ActivationStep.work);
    state = AsyncData((state.valueOrNull ?? const NewUserActivationState(active: true)).copyWith(active: true, step: ActivationStep.work, priority: value));
  }

  Future<void> createFirstWork() async {
    final current = state.valueOrNull ?? const NewUserActivationState(active: true);
    final priority = current.priority?.trim();
    final auth = await ref.read(authServiceProvider).authStateChanges.first;
    if (auth.uid == null) throw StateError('Your session has expired. Please sign in again.');
    if (priority == null || priority.isEmpty) throw StateError('Add your first priority before creating work.');

    final project = await ref.read(projectRepositoryProvider).createProject(uid: auth.uid!, name: priority, description: 'Your first Pulse project.');
    final task = await ref.read(taskRepositoryProvider).createTask(
          uid: auth.uid!,
          title: priority,
          dueDate: DateTime.now(),
          projectId: project.id,
          priority: 1,
        );
    await _prefs.setString(_projectKey, project.id);
    await _prefs.setString(_taskKey, task.id);
    await _setStep(ActivationStep.focus);
    state = AsyncData(current.copyWith(active: true, step: ActivationStep.focus, projectId: project.id, taskId: task.id));
  }

  Future<void> markFocusCompleted() async {
    await _setStep(ActivationStep.firstWin);
    state = AsyncData((state.valueOrNull ?? const NewUserActivationState(active: true)).copyWith(active: true, step: ActivationStep.firstWin));
  }

  Future<void> complete() async {
    await _prefs.setBool(_activeKey, false);
    await _setStep(ActivationStep.complete);
    state = AsyncData((state.valueOrNull ?? const NewUserActivationState()).copyWith(active: false, step: ActivationStep.complete));
  }

  Future<void> _setStep(ActivationStep step) => _prefs.setInt(_stepKey, step.index);
}

final newUserActivationProvider = AsyncNotifierProvider<NewUserActivationController, NewUserActivationState>(NewUserActivationController.new);
