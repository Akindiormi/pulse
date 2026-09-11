import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/backend/trusted_challenge_backend.dart';
import '../../../core/di/providers.dart';
import '../../../models/focus_session_model.dart';
import '../../../models/project_model.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';

final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeViewData>(HomeController.new);

class HomeViewData {
  const HomeViewData({required this.user, required this.tasks, required this.projects, required this.focusSessions});
  final UserModel user;
  final List<Task> tasks;
  final List<Project> projects;
  final List<FocusSession> focusSessions;

  List<Task> get todayTasks => tasks.where((task) => task.isOpen && _isTodayOrOverdue(task.dueDate)).toList(growable: false);
  List<Task> get upcomingTasks => tasks.where((task) => task.isOpen && task.dueDate != null && task.dueDate!.isAfter(_endOfToday())).toList(growable: false);
  List<Task> get completedTasks => tasks.where((task) => task.isCompleted).toList(growable: false);
  List<Task> get completedToday => completedTasks.where((task) => task.completedAt != null && _isSameDay(task.completedAt!, DateTime.now())).toList(growable: false);
  List<FocusSession> get todayFocusSessions => focusSessions.where((session) => _isSameDay(session.startedAt, DateTime.now())).toList(growable: false);
  FocusSession? get activeFocusSession => focusSessions.where((session) => session.status.isActive).firstOrNull;
  int get focusTodaySeconds => todayFocusSessions.fold<int>(0, (sum, session) => sum + session.activeDurationSeconds);
  Task? get nextTask {
    final open = todayTasks;
    if (open.isEmpty) return null;
    final sorted = [...open]..sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      if (priority != 0) return priority;
      final aDate = a.dueDate ?? DateTime(9999);
      final bDate = b.dueDate ?? DateTime(9999);
      return aDate.compareTo(bDate);
    });
    return sorted.first;
  }

  int projectOpenTaskCount(String projectId) => tasks.where((task) => task.projectId == projectId && task.isOpen).length;
  int projectCompletedTaskCount(String projectId) => tasks.where((task) => task.projectId == projectId && task.isCompleted).length;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _endOfToday() {
    final today = _today();
    return today.add(const Duration(days: 1));
  }

  static bool _isTodayOrOverdue(DateTime? date) {
    if (date == null) return true;
    final today = _today();
    final endOfToday = today.add(const Duration(days: 1));
    return date.isBefore(endOfToday);
  }

  static bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
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
    final repository = ref.read(userRepositoryProvider);
    final user = await repository.getUserModel(uid);
    if (user == null) throw const TrustedBackendException(TrustedBackendErrorCode.notFound, 'Your Pulse profile could not be found.');

    final syncedUser = await _syncDeviceTimezone(uid: uid, user: user);
    final results = await Future.wait<dynamic>([
      ref.read(taskRepositoryProvider).getTasks(uid: uid),
      ref.read(projectRepositoryProvider).getProjects(uid: uid),
      ref.read(focusRepositoryProvider).getSessionHistory(limit: 100),
    ]);
    return HomeViewData(
      user: syncedUser,
      tasks: results[0] as List<Task>,
      projects: results[1] as List<Project>,
      focusSessions: results[2] as List<FocusSession>,
    );
  }

  Future<UserModel> _syncDeviceTimezone({required String uid, required UserModel user}) async {
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      if (deviceTimezone.identifier == user.timezone) return user;
      await ref.read(userRepositoryProvider).updateProfileFields(uid: uid, fields: <String, dynamic>{'timezone': deviceTimezone.identifier});
      return user.copyWith(timezone: deviceTimezone.identifier);
    } catch (_) {
      return user;
    }
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
    state = AsyncData(HomeViewData(user: current.user, tasks: [task, ...current.tasks], projects: current.projects, focusSessions: current.focusSessions));
  }

  Future<TaskCompletionResult?> completeTask(String taskId) async {
    final current = state.valueOrNull;
    if (current == null) return null;
    final result = await ref.read(taskRepositoryProvider).completeTask(taskId: taskId);
    if (result.completed) {
      final user = current.user.copyWith(xp: result.newXP, level: result.newLevel, currentStreak: result.newStreak, longestStreak: result.longestStreak, totalActivities: result.totalActivities);
      final tasks = current.tasks.map((task) => task.id == taskId ? task.copyWith(status: TaskStatus.completed, completedAt: result.completedAt) : task).toList(growable: false);
      state = AsyncData(HomeViewData(user: user, tasks: tasks, projects: current.projects, focusSessions: current.focusSessions));
    }
    return result;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
