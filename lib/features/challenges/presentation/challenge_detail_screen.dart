import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/trusted_challenge_backend.dart';
import '../../../core/motion/pulse_motion_attachment.dart';
import '../../../core/motion/pulse_motion_state.dart';
import '../../../core/widgets/pulse_button.dart';
import '../../../core/widgets/pulse_card.dart';
import '../../../core/widgets/pulse_feedback.dart';
import '../../../core/widgets/pulse_states.dart';
import '../../home/application/home_controller.dart';
import '../application/challenge_detail_controller.dart';

class ChallengeDetailScreen extends ConsumerWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(challengeDetailControllerProvider(challengeId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: 'back',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('today’s challenge'),
      ),
      body: SafeArea(
        child: asyncData.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Column(children: [
              PulseCardLoading(height: 150),
              SizedBox(height: 16),
              PulseCardLoading(height: 260),
              SizedBox(height: 16),
              PulseCardLoading(height: 58),
            ]),
          ),
          error: (error, _) => _ErrorBody(error: error, onRetry: () => ref.read(challengeDetailControllerProvider(challengeId).notifier).retry()),
          data: (data) => _LoadedBody(challengeId: challengeId, data: data),
        ),
      ),
    );
  }
}

class _LoadedBody extends ConsumerWidget {
  const _LoadedBody({required this.challengeId, required this.data});

  final String challengeId;
  final ChallengeDetailViewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(challengeDetailControllerProvider(challengeId).notifier);
    final challenge = data.challenge;

    if (data.phase == ChallengeDetailPhase.completed) {
      return PulseMotionBoundaryV2(
        intent: PulseMotionIntent.challengeCompletion,
        state: data.challengeMotionState,
        child: _CompletionBody(data: data, onHome: () => _goHome(context, ref)),
      );
    }
    if (data.phase == ChallengeDetailPhase.alreadyCompleted) {
      return PulseMotionBoundaryV2(
        intent: PulseMotionIntent.challengeCompletion,
        state: data.challengeMotionState,
        child: _AlreadyCompletedBody(onHome: () => _goHome(context, ref)),
      );
    }

    final isStarting = data.phase == ChallengeDetailPhase.starting;
    final isCompleting = data.phase == ChallengeDetailPhase.completing;
    final canStart = data.phase == ChallengeDetailPhase.ready;
    final canComplete = data.phase == ChallengeDetailPhase.active || data.phase == ChallengeDetailPhase.ready;

    return PulseMotionBoundaryV2(
      intent: PulseMotionIntent.challengeInteraction,
      state: data.challengeMotionState,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            sliver: SliverList(delegate: SliverChildListDelegate([
              PulseMotionAttachment(
                intent: PulseMotionIntent.challengeReveal,
                state: data.challengeMotionState,
                child: Semantics(header: true, child: Text('a small action. a real win.', style: Theme.of(context).textTheme.labelLarge)),
              ),
              const SizedBox(height: 12),
              Text(challenge.title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _MetaChip(label: _pretty(challenge.category.name)),
                _MetaChip(label: _pretty(challenge.difficulty.name)),
                if (challenge.estimatedMinutes > 0) _MetaChip(label: '${challenge.estimatedMinutes} min'),
                if (challenge.estimatedCost != null) _MetaChip(label: 'cost ${challenge.estimatedCost!.toStringAsFixed(0)}'),
              ]),
              const SizedBox(height: 28),
              PulseCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('what to do', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(challenge.description, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  Semantics(
                    label: 'reward: ${challenge.xpReward} XP',
                    child: Row(children: [
                      const Icon(Icons.bolt_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('${challenge.xpReward} XP', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 8),
                      Expanded(child: Text('after the backend confirms completion', style: Theme.of(context).textTheme.bodySmall)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              if (data.phase == ChallengeDetailPhase.active) ...[
                Text('do it at your pace.', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('when you’ve actually finished, tap complete. pulse will verify the completion before showing any reward.', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 18),
              ],
              PulseMotionBoundaryV2(
                intent: PulseMotionIntent.challengeInteraction,
                state: isCompleting ? PulseCompletionMotionState.pending : data.challengeMotionState,
                child: PulseButton(
                  label: isStarting ? 'starting…' : data.phase == ChallengeDetailPhase.active ? 'complete challenge' : 'start challenge',
                  loading: isStarting || isCompleting,
                  onPressed: isCompleting ? null : canStart ? controller.start : canComplete ? controller.complete : null,
                  icon: data.phase == ChallengeDetailPhase.active ? Icons.check_rounded : Icons.play_arrow_rounded,
                  expand: true,
                ),
              ),
              if (isCompleting) ...[
                const SizedBox(height: 14),
                const PulseInlineLoading(label: 'checking your completion…'),
              ],
            ])),
          ),
        ],
      ),
    );
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.invalidate(homeControllerProvider);
    context.go('/home');
  }

  String _pretty(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

class _CompletionBody extends StatelessWidget {
  const _CompletionBody({required this.data, required this.onHome});

  final ChallengeDetailViewData data;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final result = data.completion!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        PulseMotionAttachment(
          intent: PulseMotionIntent.challengeReward,
          state: PulseCompletionMotionState.success,
          child: PulseCompletionSurface(
            event: PulseCelebrationEvent.completion,
            xpAwarded: result.xpAwarded,
            streak: result.currentStreak,
            achievementIds: result.newAchievements,
            previousLevel: result.previousLevel,
            newLevel: result.newLevel,
          ),
          excludeFromSemantics: false,
        ),
        const SizedBox(height: 18),
        if (result.leveledUp) ...[
          PulseMotionAttachment(
            intent: PulseMotionIntent.levelUp,
            state: PulseProgressMotionState.levelUp,
            child: PulseLevelUpSurface(level: result.newLevel),
            excludeFromSemantics: false,
          ),
          const SizedBox(height: 18),
        ],
        Text('you’re done for today.', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('your progression was updated by the trusted completion service. home will refresh from the authoritative state.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        PulseButton(label: 'back to home', onPressed: onHome, icon: Icons.arrow_forward_rounded, expand: true),
      ],
    );
  }
}

class _AlreadyCompletedBody extends StatelessWidget {
  const _AlreadyCompletedBody({required this.onHome});
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          PulseFeedbackSurface(
            semanticLabel: 'challenge already completed',
            icon: Icons.check_circle_outline_rounded,
            title: 'already done.',
            detail: 'this challenge has already been completed. no new reward was added.',
          ),
          const SizedBox(height: 24),
          PulseButton(label: 'back to home', onPressed: onHome, expand: true),
        ],
      );
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error is TrustedBackendException && (error as TrustedBackendException).code == TrustedBackendErrorCode.unavailable) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          PulseOfflineState(onRetry: onRetry),
          const SizedBox(height: 18),
          Text('we couldn’t reach Pulse right now. no completion or reward was recorded.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
    }
    return PulseErrorState(message: 'we couldn’t load this challenge. please try again.', onRetry: onRetry);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(99)),
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
      );
}
