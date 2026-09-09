import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/backend/trusted_challenge_backend.dart';
import '../../../core/di/providers.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';

final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeViewData>(HomeController.new);

class HomeViewData {
  const HomeViewData({required this.user, required this.tasks});
  final UserModel user;
  final List<Task> tasks;

  List<Task> get todayTasks => tasks.where((task) => task.isOpen && _isTodayOrOverdue(task.dueDate)).toList(growable: false);
  List<Task> get upcomingTasks => tasks.where((task) => task.isOpen && task.dueDate != null && task.dueDate!.isAfter(_today())).toList(growable: false);
  List<Task> get completedTasks => tasks.where((task) => task.isCompleted).toList(growable: false);

  static DateTime _today() { final now = DateTime.now(); return DateTime(now.year, now.month, now.day); }
  static bool _isTodayOrOverdue(DateTime? date) => date == null || !date.isAfter(_today());
}

class HomeController extends AsyncNotifier<HomeViewData> {
  @override
  Future<HomeViewData> build() => _load();

  Future<HomeViewData> _load() async {
    final authState = await ref.read(authServiceProvider).authStateChanges.first;
    if (authState.status != AuthStatus.authenticated || authState.uid == null) {
      throw const TrustedBackendException(TrustedBackendErrorCode.unauthenticated, 'Sign in to see your Pulse.');
    }
    final uid = authState.uid!;
    final user = await ref.read(userRepositoryProvider).getUserModel(uid);
    if (user == null) throw const TrustedBackendException(TrustedBackendErrorCode.notFound, 'Your Pulse profile could not be found.');
    final tasks = await ref.read(taskRepositoryProvider).getTasks(uid: uid);
    return HomeViewData(user: user, tasks: tasks);
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> addTask(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final current = state.valueOrNull;
    if (current == null) return;
    final task = await ref.read(taskRepositoryProvider).createTask(uid: current.user.uid, title: trimmed, dueDate: DateTime.now());
    state = AsyncData(HomeViewData(user: current.user, tasks: [task, ...current.tasks]));
  }

  Future<TaskCompletionResult?> completeTask(String taskId) async {
    final current = state.valueOrNull;
    if (current == null) return null;
    final result = await ref.read(taskRepositoryProvider).completeTask(taskId: taskId);
    if (result.completed) {
      final user = current.user.copyWith(xp: result.newXP, level: result.newLevel, currentStreak: result.newStreak, longestStreak: result.longestStreak, totalActivities: result.totalActivities);
      final tasks = current.tasks.map((task) => task.id == taskId ? task.copyWith(status: TaskStatus.completed, completedAt: result.completedAt) : task).toList(growable: false);
      state = AsyncData(HomeViewData(user: user, tasks: tasks));
    }
    return result;
  }
}
