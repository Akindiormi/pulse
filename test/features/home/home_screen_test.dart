import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/core/backend/trusted_challenge_backend.dart';
import 'package:pulse/core/theme/app_theme.dart';
import 'package:pulse/core/widgets/pulse_states.dart';
import 'package:pulse/features/home/application/home_controller.dart';
import 'package:pulse/features/home/presentation/home_screen.dart';
import 'package:pulse/models/focus_session_model.dart';
import 'package:pulse/models/project_model.dart';
import 'package:pulse/models/task_model.dart';
import 'package:pulse/models/user_model.dart';

UserModel _user() => const UserModel(uid: 'user-1', displayName: 'Akin', xp: 50, level: 1, currentStreak: 4, longestStreak: 7);
Task _task(String id, String title, {TaskStatus status = TaskStatus.todo, DateTime? dueDate, int priority = 0, DateTime? completedAt, String? projectId}) => Task(id: id, userId: 'user-1', title: title, status: status, dueDate: dueDate ?? DateTime.now(), priority: priority, completedAt: completedAt, projectId: projectId);
FocusSession _focus({FocusSessionStatus status = FocusSessionStatus.completed, int seconds = 1500, DateTime? startedAt}) => FocusSession(id: 'focus-1', userId: 'user-1', status: status, plannedDurationSeconds: 1500, startedAt: startedAt ?? DateTime.now(), activeDurationSeconds: seconds, taskId: 'task-1');
HomeViewData _data({List<Task>? tasks, List<FocusSession>? focusSessions, List<Project>? projects}) => HomeViewData(user: _user(), tasks: tasks ?? <Task>[_task('task-1', 'finish pharmacology assignment', priority: 1)], projects: projects ?? const [], focusSessions: focusSessions ?? const []);
Widget _app(AsyncValue<HomeViewData> value) => ProviderScope(overrides: [homeControllerProvider.overrideWith(() => _FakeHomeController(value))], child: MaterialApp(theme: buildAppTheme(Brightness.light), darkTheme: buildAppTheme(Brightness.dark), home: const Scaffold(body: HomeScreen())));

void main() {
  testWidgets('loaded Home presents Today and the next action', (tester) async { await tester.pumpWidget(_app(AsyncData(_data()))); await tester.pump(); expect(find.textContaining('Akin'), findsOneWidget); expect(find.text('today'), findsOneWidget); expect(find.text('finish pharmacology assignment'), findsWidgets); expect(find.text('what’s next'), findsOneWidget); expect(find.text('start focus'), findsOneWidget); });
  testWidgets('Home shows real Focus and completed-today summary', (tester) async { final now = DateTime.now(); final done = _task('task-2', 'done task', status: TaskStatus.completed, completedAt: now); await tester.pumpWidget(_app(AsyncData(_data(tasks: [done], focusSessions: [_focus(startedAt: now)])))); await tester.pump(); expect(find.text('25m focused'), findsOneWidget); expect(find.text('done today'), findsNWidgets(2)); expect(find.text('1'), findsOneWidget); });
  testWidgets('Home surfaces real project movement', (tester) async { final project = const Project(id: 'project-1', userId: 'user-1', name: 'Launch website'); final tasks = [_task('task-1', 'write copy', status: TaskStatus.completed, projectId: project.id, completedAt: DateTime(2026, 9, 10)), _task('task-2', 'publish site', projectId: project.id)]; await tester.pumpWidget(_app(AsyncData(_data(tasks: tasks, projects: [project])))); await tester.pump(); await tester.scrollUntilVisible(find.text('projects'), 500); expect(find.text('projects'), findsOneWidget); expect(find.text('Launch website'), findsOneWidget); expect(find.text('1 of 2 tasks done'), findsOneWidget); });
  testWidgets('Home handles projects with no tasks and completed projects', (tester) async { final empty = const Project(id: 'project-1', userId: 'user-1', name: 'No tasks yet'); final completed = const Project(id: 'project-2', userId: 'user-1', name: 'Finished', status: ProjectStatus.completed); await tester.pumpWidget(_app(AsyncData(_data(projects: [empty, completed])))); await tester.pump(); await tester.scrollUntilVisible(find.text('No tasks yet'), 500); expect(find.text('No tasks yet'), findsOneWidget); expect(find.text('no tasks yet'), findsOneWidget); expect(find.text('Finished'), findsOneWidget); expect(find.text('complete'), findsOneWidget); });
  testWidgets('loading Home renders loading foundations', (tester) async { await tester.pumpWidget(_app(const AsyncLoading())); expect(find.byType(PulseCardLoading), findsWidgets); });
  testWidgets('empty Today shows quick-add prompt', (tester) async { await tester.pumpWidget(_app(AsyncData(_data(tasks: const <Task>[])))); await tester.pump(); expect(find.text('nothing scheduled for today'), findsOneWidget); expect(find.byType(TextField), findsOneWidget); });
  testWidgets('completed tasks are visibly completed', (tester) async { await tester.pumpWidget(_app(AsyncData(_data(tasks: [_task('task-2', 'done task', status: TaskStatus.completed, completedAt: DateTime(2026, 9, 10))])))); await tester.pump(); final text = tester.widget<Text>(find.text('done task')); expect(text.style?.decoration, TextDecoration.lineThrough); });
  testWidgets('active Focus gets a continue action', (tester) async { await tester.pumpWidget(_app(AsyncData(_data(focusSessions: [_focus(status: FocusSessionStatus.running, seconds: 300)])))); await tester.pump(); expect(find.text('focus in progress'), findsOneWidget); expect(find.text('continue focus'), findsOneWidget); });
  testWidgets('backend unavailable Home renders offline state', (tester) async { const error = TrustedBackendException(TrustedBackendErrorCode.unavailable, 'service unavailable'); await tester.pumpWidget(_app(AsyncError<HomeViewData>(error, StackTrace.empty))); await tester.pump(); expect(find.text("you're offline. pulse will retry when you're connected."), findsOneWidget); });
  testWidgets('generic backend error renders safe retry state', (tester) async { const error = TrustedBackendException(TrustedBackendErrorCode.internal, 'Something went wrong on the server.'); await tester.pumpWidget(_app(AsyncError<HomeViewData>(error, StackTrace.empty))); await tester.pump(); expect(find.text('Something went wrong on the server.'), findsOneWidget); expect(find.text('try again'), findsOneWidget); });
}

class _FakeHomeController extends HomeController {
  _FakeHomeController(this.value);
  final AsyncValue<HomeViewData> value;
  @override
  Future<HomeViewData> build() { if (value is AsyncLoading<HomeViewData>) return Completer<HomeViewData>().future; if (value is AsyncError<HomeViewData>) return Future<HomeViewData>.error(value.error!, value.stackTrace!); return Future.value(value.requireValue); }
}
