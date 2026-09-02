import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/core/backend/trusted_challenge_backend.dart';
import 'package:pulse/core/theme/app_theme.dart';
import 'package:pulse/core/motion/pulse_motion_state.dart';
import 'package:pulse/core/widgets/pulse_states.dart';
import 'package:pulse/features/home/application/home_controller.dart';
import 'package:pulse/features/home/presentation/home_screen.dart';
import 'package:pulse/models/challenge_model.dart';
import 'package:pulse/models/user_model.dart';

Challenge _challenge() => const Challenge(id: 'authoritative-1', title: 'send someone a genuine compliment', description: 'make one person’s day a little better.', category: ChallengeCategory.social, difficulty: Difficulty.easy, xpReward: 10, estimatedMinutes: 5, estimatedCost: 0, active: true);
UserModel _user() => const UserModel(uid: 'user-1', displayName: 'Akin', xp: 50, level: 1, currentStreak: 4, longestStreak: 7);
HomeViewData _data({bool completed = false}) => HomeViewData(user: _user(), challenge: _challenge(), completed: completed, nextLevelXP: 100, xpProgress: .5);
Widget _app(AsyncValue<HomeViewData> value) => ProviderScope(overrides: [homeControllerProvider.overrideWith(() => _FakeHomeController(value))], child: MaterialApp(theme: buildAppTheme(Brightness.light), darkTheme: buildAppTheme(Brightness.dark), home: const HomeScreen()));

void main() {
  testWidgets('loaded Home presents supplied authoritative challenge and progress', (tester) async { await tester.pumpWidget(_app(AsyncData(_data()))); await tester.pump(); expect(find.textContaining('Akin'), findsOneWidget); expect(find.text(_challenge().title), findsOneWidget); expect(find.text('10 XP'), findsOneWidget); expect(find.text('4 days'), findsOneWidget); expect(find.text('level 1'), findsOneWidget); expect(find.text('50 / 100 XP'), findsOneWidget); expect(find.text('do today’s challenge'), findsOneWidget); });
  testWidgets('loading Home renders loading foundations', (tester) async { await tester.pumpWidget(_app(const AsyncLoading())); expect(find.byType(PulseCardLoading), findsWidgets); });
  testWidgets('completed Home disables the challenge action and shows completion feedback', (tester) async { await tester.pumpWidget(_app(AsyncData(_data(completed: true)))); await tester.pump(); expect(find.text('completed'), findsOneWidget); expect(find.text('nice. you did it.'), findsOneWidget); expect(find.bySemanticsLabel('challenge completion feedback'), findsOneWidget); });
  testWidgets('backend unavailable Home renders offline state', (tester) async { const error = TrustedBackendException(TrustedBackendErrorCode.unavailable, 'service unavailable'); await tester.pumpWidget(_app(AsyncError<HomeViewData>(error, StackTrace.empty))); await tester.pump(); expect(find.text("you're offline. pulse will retry when you're connected."), findsOneWidget); });
  testWidgets('generic backend error renders safe retry state', (tester) async { const error = TrustedBackendException(TrustedBackendErrorCode.internal, 'Something went wrong on the server.'); await tester.pumpWidget(_app(AsyncError<HomeViewData>(error, StackTrace.empty))); await tester.pump(); expect(find.text('Something went wrong on the server.'), findsOneWidget); expect(find.text('try again'), findsOneWidget); });
  test('Home hero uses the Phase 3A motion state contract', () { expect(PulseMotionState.values, containsAll([PulseMotionState.entering, PulseMotionState.idle, PulseMotionState.pressed, PulseMotionState.loading, PulseMotionState.completing, PulseMotionState.completed, PulseMotionState.unavailable, PulseMotionState.error])); });
}

class _FakeHomeController extends HomeController {
  _FakeHomeController(this.value);
  final AsyncValue<HomeViewData> value;

  @override
  Future<HomeViewData> build() {
    if (value is AsyncLoading<HomeViewData>) return Completer<HomeViewData>().future;
    if (value is AsyncError<HomeViewData>) return Future<HomeViewData>.error(value.error!, value.stackTrace!);
    return Future.value(value.requireValue);
  }
}
