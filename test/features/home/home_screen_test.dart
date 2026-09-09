import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/core/backend/trusted_challenge_backend.dart';
import 'package:pulse/core/theme/app_theme.dart';
import 'package:pulse/core/widgets/pulse_states.dart';
import 'package:pulse/features/home/application/home_controller.dart';
import 'package:pulse/features/home/presentation/home_screen.dart';
import 'package:pulse/models/task_model.dart';
import 'package:pulse/models/user_model.dart';

UserModel _user() => const UserModel(uid: 'user-1', displayName: 'Akin', xp: 50, level: 1, currentStreak: 4, longestStreak: 7);
Task _task(String id, String title, {TaskStatus status = TaskStatus.todo, DateTime? dueDate}) => Task(id: id, userId: 'user-1', title: title, status: status, dueDate: dueDate ?? DateTime.now());
HomeViewData _data({List<Task>? tasks}) => HomeViewData(user: _user(), tasks: tasks ?? <Task>[_task('task-1', 'finish pharmacology assignment')]);
Widget _app(AsyncValue<HomeViewData> value) => ProviderScope(overrides: [homeControllerProvider.overrideWith(() => _FakeHomeController(value))], child: MaterialApp(theme: buildAppTheme(Brightness.light), darkTheme: buildAppTheme(Brightness.dark), home: const Scaffold(body: HomeScreen())));

void main() {
  testWidgets('loaded Home presents Today and supplied tasks', (tester) async { await tester.pumpWidget(_app(AsyncData(_data()))); await tester.pump(); expect(find.textContaining('Akin'), findsOneWidget); expect(find.text('today'), findsOneWidget); expect(find.text('finish pharmacology assignment'), findsOneWidget); expect(find.text('4 days'), findsOneWidget); });
  testWidgets('loading Home renders loading foundations', (tester) async { await tester.pumpWidget(_app(const AsyncLoading())); expect(find.byType(PulseCardLoading), findsWidgets); });
  testWidgets('empty Today shows quick-add prompt', (tester) async { await tester.pumpWidget(_app(AsyncData(_data(tasks: const <Task>[])))); await tester.pump(); expect(find.text('what’s one thing worth getting done today?'), findsOneWidget); expect(find.byType(TextField), findsOneWidget); });
  testWidgets('completed tasks are visibly completed', (tester) async { await tester.pumpWidget(_app(AsyncData(_data(tasks: [_task('task-2', 'done task', status: TaskStatus.completed)])))); await tester.pump(); final text = tester.widget<Text>(find.text('done task')); expect(text.style?.decoration, TextDecoration.lineThrough); });
  testWidgets('backend unavailable Home renders offline state', (tester) async { const error = TrustedBackendException(TrustedBackendErrorCode.unavailable, 'service unavailable'); await tester.pumpWidget(_app(AsyncError<HomeViewData>(error, StackTrace.empty))); await tester.pump(); expect(find.text("you're offline. pulse will retry when you're connected."), findsOneWidget); });
  testWidgets('generic backend error renders safe retry state', (tester) async { const error = TrustedBackendException(TrustedBackendErrorCode.internal, 'Something went wrong on the server.'); await tester.pumpWidget(_app(AsyncError<HomeViewData>(error, StackTrace.empty))); await tester.pump(); expect(find.text('Something went wrong on the server.'), findsOneWidget); expect(find.text('try again'), findsOneWidget); });
}

class _FakeHomeController extends HomeController {
  _FakeHomeController(this.value);
  final AsyncValue<HomeViewData> value;
  @override
  Future<HomeViewData> build() { if (value is AsyncLoading<HomeViewData>) return Completer<HomeViewData>().future; if (value is AsyncError<HomeViewData>) return Future<HomeViewData>.error(value.error!, value.stackTrace!); return Future.value(value.requireValue); }
}
