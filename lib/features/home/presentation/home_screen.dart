import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/trusted_challenge_backend.dart';
import '../../../core/motion/pulse_motion_state.dart';
import '../../../core/widgets/pulse_button.dart';
import '../../../core/widgets/pulse_feedback.dart';
import '../../../core/widgets/pulse_hero_challenge.dart';
import '../../../core/widgets/pulse_progress.dart';
import '../../../core/widgets/pulse_streak.dart';
import '../application/home_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeControllerProvider);
    return home.when(
      loading: () => const _HomeLoading(),
      error: (error, _) => _HomeError(error: error, onRetry: () => ref.read(homeControllerProvider.notifier).retry()),
      data: (data) => _HomeLoaded(data: data),
    );
  }
}

class _HomeLoaded extends StatelessWidget {
  const _HomeLoaded({required this.data});
  final HomeViewData data;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'good morning';
    if (hour < 17) return 'good afternoon';
    return 'good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = data.user.displayName?.trim();
    final greeting = name == null || name.isEmpty ? _greeting() : '${_greeting()}, ${name.split(' ').first}';
    final progress = _levelProgress(data.user.xp, data.user.level);
    final heroState = data.completed ? PulseMotionState.completed : PulseMotionState.idle;

    return RefreshIndicator(
      onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 200)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          Text(greeting, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: PulseStreak(currentStreak: data.user.currentStreak, longestStreak: data.user.longestStreak)),
              const SizedBox(width: 12),
              Expanded(child: PulseXpProgress(currentXP: data.user.xp, level: data.user.level, progress: progress)),
            ],
          ),
          const SizedBox(height: 28),
          PulseMotionBoundary(
            state: heroState,
            child: PulseHeroChallenge(
              challenge: data.challenge,
              motionState: heroState,
              completed: data.completed,
              onPressed: data.completed ? null : () => context.push('/challenge/${data.challenge.id}'),
            ),
          ),
          const SizedBox(height: 20),
          if (data.completed)
            PulseCompletionSurface(
              title: 'today is complete',
              detail: 'you showed up today. your reward is already recorded.',
              onAction: () {},
              actionLabel: 'come back tomorrow',
            )
          else
            _ProgressHint(level: data.user.level, xp: data.user.xp),
        ],
      ),
    );
  }

  double _levelProgress(int xp, int level) {
    // Presentation only: uses the existing level boundaries, not a reward calculation.
    final floor = (level - 1) * 1000;
    final ceiling = level * 1000;
    if (ceiling <= floor) return 0;
    return ((xp - floor) / (ceiling - floor)).clamp(0.0, 1.0);
  }
}

class _ProgressHint extends StatelessWidget {
  const _ProgressHint({required this.level, required this.xp});
  final int level;
  final int xp;

  @override
  Widget build(BuildContext context) => PulseCard(
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text('level $level · $xp XP earned so far', style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: const [
          PulseCardLoading(height: 28),
          SizedBox(height: 18),
          PulseCardLoading(height: 82),
          SizedBox(height: 28),
          PulseCardLoading(height: 300),
          SizedBox(height: 20),
          PulseCardLoading(height: 72),
        ],
      );
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final unavailable = error is TrustedBackendException && (error as TrustedBackendException).code == TrustedBackendErrorCode.unavailable;
    if (unavailable) return PulseOfflineState(onRetry: onRetry);
    final message = error is TrustedBackendException ? (error as TrustedBackendException).message : 'we couldn’t load today’s Pulse.';
    return PulseErrorState(message: message, onRetry: onRetry);
  }
}
