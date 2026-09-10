import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';

/// Persists only the resume pointer for the first-use journey. Real work,
/// focus sessions and progress remain in the application's repositories.
enum ActivationStep { personal, priority, work, focus, firstWin, complete }

class NewUserActivationState {
  const NewUserActivationState({
    this.active = false,
    this.step = ActivationStep.personal,
    this.area,
    this.priority,
    this.projectId,
    this.taskId,
  });

  final bool active;
  final ActivationStep step;
  final String? area;
  final String? priority;
  final String? projectId;
  final String? taskId;

  NewUserActivationState copyWith({
    bool? active,
    ActivationStep? step,
    String? area,
    String? priority,
    String? projectId,
    String? taskId,
  }) => NewUserActivationState(
        active: active ?? this.active,
        step: step ?? this.step,
        area: area ?? this.area,
        priority: priority ?? this.priority,
        projectId: projectId ?? this.projectId,
        taskId: taskId ?? this.taskId,
      );
}

class NewUserActivationController
    extends AsyncNotifier<NewUserActivationState> {
  SharedPreferencesAsync get _prefs => SharedPreferencesAsync();

  Future<String> _uid() async {
    final auth = await ref.read(authServiceProvider).authStateChanges.first;
    final uid = auth.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Your session has expired. Please sign in again.');
    }
    return uid;
  }

  String _key(String base, String uid) => '$base.$uid';

  @override
  Future<NewUserActivationState> build() async {
    final uid = await _uid();
    final active = await _prefs.getBool(_key('pulse.activation.active', uid)) ?? false;
    final stepIndex = await _prefs.getInt(_key('pulse.activation.step', uid)) ?? 0;
    final safeIndex = stepIndex.clamp(0, ActivationStep.values.length - 1);
    final step = ActivationStep.values[safeIndex];
    return NewUserActivationState(
      active: active,
      step: step,
      area: await _prefs.getString(_key('pulse.activation.area', uid)),
      priority: await _prefs.getString(_key('pulse.activation.priority', uid)),
      projectId: await _prefs.getString(_key('pulse.activation.project_id', uid)),
      taskId: await _prefs.getString(_key('pulse.activation.task_id', uid)),
    );
  }

  Future<void> begin() async {
    final uid = await _uid();
    await _prefs.setBool(_key('pulse.activation.active', uid), true);
    await _prefs.setInt(_key('pulse.activation.step', uid), ActivationStep.personal.index);
    await _prefs.remove(_key('pulse.activation.area', uid));
    await _prefs.remove(_key('pulse.activation.priority', uid));
    await _prefs.remove(_key('pulse.activation.project_id', uid));
    await _prefs.remove(_key('pulse.activation.task_id', uid));
    state = const AsyncData(NewUserActivationState(active: true));
  }

  Future<void> savePersonal({
    required String displayName,
    required String area,
  }) async {
    final uid = await _uid();
    final current = state.valueOrNull ?? const NewUserActivationState(active: true);
    await ref.read(userRepositoryProvider).createOrUpdateUser(
          uid: uid,
          displayName: displayName.trim(),
        );
    await _prefs.setString(_key('pulse.activation.area', uid), area);
    await _setStep(ActivationStep.priority, uid);
    state = AsyncData(current.copyWith(
      active: true,
      step: ActivationStep.priority,
      area: area,
    ));
  }

  Future<void> savePriority(String priority) async {
    final uid = await _uid();
    final value = priority.trim();
    if (value.isEmpty) {
      throw ArgumentError('Tell Pulse what matters right now.');
    }
    await _prefs.setString(_key('pulse.activation.priority', uid), value);
    await _setStep(ActivationStep.work, uid);
    state = AsyncData(
      (state.valueOrNull ?? const NewUserActivationState(active: true)).copyWith(
        active: true,
        step: ActivationStep.work,
        priority: value,
      ),
    );
  }

  Future<void> createFirstWork() async {
    final uid = await _uid();
    final current = state.valueOrNull ?? const NewUserActivationState(active: true);
    final priority = current.priority?.trim();
    if (priority == null || priority.isEmpty) {
      throw StateError('Add your first priority before creating work.');
    }

    // Idempotency guard: if the project/task were created before a network
    // interruption, resume the existing activation rather than creating a
    // second copy.
    if (current.projectId != null && current.taskId != null) {
      await _setStep(ActivationStep.focus, uid);
      state = AsyncData(current.copyWith(active: true, step: ActivationStep.focus));
      return;
    }

    final project = await ref.read(projectRepositoryProvider).createProject(
          uid: uid,
          name: priority,
          description: 'Your first Pulse project.',
        );
    final task = await ref.read(taskRepositoryProvider).createTask(
          uid: uid,
          title: priority,
          dueDate: DateTime.now(),
          projectId: project.id,
          priority: 1,
        );
    await _prefs.setString(_key('pulse.activation.project_id', uid), project.id);
    await _prefs.setString(_key('pulse.activation.task_id', uid), task.id);
    await _setStep(ActivationStep.focus, uid);
    state = AsyncData(current.copyWith(
      active: true,
      step: ActivationStep.focus,
      projectId: project.id,
      taskId: task.id,
    ));
  }

  Future<void> markFocusCompleted() async {
    final uid = await _uid();
    await _setStep(ActivationStep.firstWin, uid);
    state = AsyncData(
      (state.valueOrNull ?? const NewUserActivationState(active: true)).copyWith(
        active: true,
        step: ActivationStep.firstWin,
      ),
    );
  }

  Future<void> complete() async {
    final uid = await _uid();
    await _prefs.setBool(_key('pulse.activation.active', uid), false);
    await _setStep(ActivationStep.complete, uid);
    state = AsyncData(
      (state.valueOrNull ?? const NewUserActivationState()).copyWith(
        active: false,
        step: ActivationStep.complete,
      ),
    );
  }

  Future<void> _setStep(ActivationStep step, String uid) =>
      _prefs.setInt(_key('pulse.activation.step', uid), step.index);
}

final newUserActivationProvider = AsyncNotifierProvider<
    NewUserActivationController, NewUserActivationState>(
  NewUserActivationController.new,
);
