import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/core/backend/trusted_challenge_backend.dart';
import 'package:pulse/core/motion/pulse_motion_state.dart';
import 'package:pulse/core/theme/app_theme.dart';
import 'package:pulse/core/widgets/pulse_card.dart';
import 'package:pulse/core/widgets/pulse_states.dart';
import 'package:pulse/features/challenges/application/challenge_detail_controller.dart';
import 'package:pulse/features/challenges/application/complete_challenge.dart';
import 'package:pulse/features/challenges/presentation/challenge_detail_screen.dart';
import 'package:pulse/models/challenge_model.dart';

Challenge _challenge() => const Challenge(
      id: 'challenge-1',
      title: 'take a ten minute walk',
      description: 'step outside and take a calm ten minute walk.',
      category: ChallengeCategory.health,
      difficulty: Difficulty.easy,
      xpReward: 25,
      estimatedMinutes: 10,
      estimatedCost: 0,
      active: true,
    );

ChallengeDetailViewData _data({ChallengeDetailPhase phase = ChallengeDetailPhase.ready, CompletionResult? completion}) => ChallengeDetailViewData(
      challenge: _challenge(),
      phase: phase,
      completion: completion,
    );

Widget _app(AsyncValue<ChallengeDetailViewData> value) => ProviderScope(
      overrides: [challengeDetailControllerProvider('challenge-1').overrideWithValue(value)],
      child: MaterialApp(theme: buildAppTheme(Brightness.light), home: const ChallengeDetailScreen(challengeId: 'challenge-1')),
    );

void main() {
  testWidgets('loading renders polished skeletons', (tester) async {
    await tester.pumpWidget(_app(const AsyncLoading()));
    expect(find.byType(PulseCardLoading), findsWidgets);
  });

  testWidgets('loaded challenge presents supplied model data', (tester) async {
    await tester.pumpWidget(_app(AsyncData(_data())));
    await tester.pump();

    expect(find.text(_challenge().title), findsOneWidget);
    expect(find.text(_challenge().description), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    expect(find.text('25 XP'), findsOneWidget);
    expect(find.text('start challenge'), findsOneWidget);
  });

  testWidgets('active state exposes completion action', (tester) async {
    await tester.pumpWidget(_app(AsyncData(_data(phase: ChallengeDetailPhase.active))));
    await tester.pump();
    expect(find.text('complete challenge'), findsOneWidget);
    expect(find.textContaining('tap complete'), findsOneWidget);
  });

  testWidgets('completing state disables the primary action and shows pending feedback', (tester) async {
    await tester.pumpWidget(_app(AsyncData(_data(phase: ChallengeDetailPhase.completing))));
    await tester.pump();
    expect(find.text('checking your completion…'), findsOneWidget);
  });

  testWidgets('successful authoritative result displays XP, streak, achievement and level-up', (tester) async {
    final result = CompletionResult(
      completed: true,
      alreadyCompleted: false,
      xpAwarded: 75,
      previousXP: 90,
      currentXP: 165,
      previousStreak: 3,
      currentStreak: 4,
      longestStreak: 4,
      previousLevel: 1,
      newLevel: 2,
      leveledUp: true,
      newAchievements: const ['FIRST_STEP'],
      events: const [],
      challengeId: 'challenge-1',
    );
    await tester.pumpWidget(_app(AsyncData(_data(phase: ChallengeDetailPhase.completed, completion: result))));
    await tester.pump();

    expect(find.text('+75 XP\nstreak: 4 days\nachievement unlocked: First Step\nlevel 1 → level 2'), findsOneWidget);
    expect(find.text('level up.'), findsOneWidget);
    expect(find.text('you reached level 2'), findsOneWidget);
  });

  testWidgets('already completed state never presents a new reward', (tester) async {
    await tester.pumpWidget(_app(AsyncData(_data(phase: ChallengeDetailPhase.alreadyCompleted))));
    await tester.pump();
    expect(find.text('already done.'), findsOneWidget);
    expect(find.textContaining('no new reward was added'), findsOneWidget);
    expect(find.textContaining('+25 XP'), findsNothing);
  });

  testWidgets('generic error renders safe retry copy', (tester) async {
    const error = TrustedBackendException(TrustedBackendErrorCode.internal, 'sensitive server detail');
    await tester.pumpWidget(_app(AsyncError<ChallengeDetailViewData>(error, StackTrace.empty)));
    await tester.pump();
    expect(find.text('we couldn’t load this challenge. please try again.'), findsOneWidget);
    expect(find.text('sensitive server detail'), findsNothing);
    expect(find.text('try again'), findsOneWidget);
  });

  testWidgets('unavailable state renders offline presentation without rewards', (tester) async {
    const error = TrustedBackendException(TrustedBackendErrorCode.unavailable, 'service unavailable');
    await tester.pumpWidget(_app(AsyncError<ChallengeDetailViewData>(error, StackTrace.empty)));
    await tester.pump();
    expect(find.text("you're offline. pulse will retry when you're connected."), findsOneWidget);
    expect(find.textContaining('no completion or reward was recorded'), findsOneWidget);
  });

  test('CompleteChallenge delegates to TrustedChallengeBackend and preserves authoritative values', () async {
    final backend = FakeTrustedChallengeBackend(
      CompleteChallengeResult(
        activityCompleted: true,
        alreadyCompleted: false,
        xpAwarded: 75,
        previousXP: 90,
        newXP: 165,
        previousStreak: 3,
        newStreak: 4,
        longestStreak: 4,
        previousLevel: 1,
        newLevel: 2,
        leveledUp: true,
        newAchievements: const ['FIRST_STEP'],
        challengeId: 'challenge-1',
      ),
    );

    final result = await CompleteChallenge(backend: backend).call();

    expect(backend.completeCalls, 1);
    expect(backend.lastIdempotencyKey, isNull);
    expect(result.xpAwarded, 75);
    expect(result.currentXP, 165);
    expect(result.currentStreak, 4);
    expect(result.newLevel, 2);
    expect(result.newAchievements, ['FIRST_STEP']);
    expect(result.events.whereType<Object>(), isNotEmpty);
  });

  test('CompleteChallenge does not invent rewards for an already completed result', () async {
    final backend = FakeTrustedChallengeBackend(
      const CompleteChallengeResult(
        activityCompleted: false,
        alreadyCompleted: true,
        xpAwarded: 0,
        previousXP: 165,
        newXP: 165,
        previousStreak: 4,
        newStreak: 4,
        longestStreak: 4,
        previousLevel: 2,
        newLevel: 2,
        leveledUp: false,
        newAchievements: [],
        challengeId: 'challenge-1',
      ),
    );

    final result = await CompleteChallenge(backend: backend).call();

    expect(result.alreadyCompleted, true);
    expect(result.xpAwarded, 0);
    expect(result.newAchievements, isEmpty);
    expect(result.events, isEmpty);
  });

  test('Phase 3C motion vocabulary exposes the required attachment states', () {
    expect(PulseMotionState.values, containsAll([
      PulseMotionState.entering,
      PulseMotionState.idle,
      PulseMotionState.pressed,
      PulseMotionState.starting,
      PulseMotionState.completing,
      PulseMotionState.completed,
      PulseMotionState.alreadyCompleted,
      PulseMotionState.error,
      PulseMotionState.unavailable,
    ]));
    expect(PulseCompletionMotionState.values, containsAll([
      PulseCompletionMotionState.pending,
      PulseCompletionMotionState.success,
      PulseCompletionMotionState.alreadyCompleted,
      PulseCompletionMotionState.error,
    ]));
    expect(PulseProgressMotionState.values, containsAll([
      PulseProgressMotionState.unchanged,
      PulseProgressMotionState.xpGained,
      PulseProgressMotionState.levelUp,
    ]));
    expect(PulseStreakMotionState.values, containsAll([
      PulseStreakMotionState.maintained,
      PulseStreakMotionState.increased,
      PulseStreakMotionState.milestone,
    ]));
    expect(PulseAchievementMotionState.values, contains(PulseAchievementMotionState.none));
  });
}

class FakeTrustedChallengeBackend implements TrustedChallengeBackend {
  FakeTrustedChallengeBackend(this.result);
  final CompleteChallengeResult result;
  int completeCalls = 0;
  String? lastIdempotencyKey;

  @override
  Future<CompleteChallengeResult> completeChallenge({String? idempotencyKey}) async {
    completeCalls += 1;
    lastIdempotencyKey = idempotencyKey;
    return result;
  }

  @override
  Future<DailyChallengeResult> getOrAssignDailyChallenge() => throw UnimplementedError();
}
