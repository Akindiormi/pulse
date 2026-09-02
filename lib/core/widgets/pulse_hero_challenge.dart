import 'package:flutter/material.dart';
import '../../models/challenge_model.dart';
import '../design/pulse_tokens.dart';
import '../motion/pulse_motion_state.dart';
import 'pulse_button.dart';
import 'pulse_card.dart';

class PulseHeroChallenge extends StatelessWidget {
  const PulseHeroChallenge({super.key, required this.challenge, this.motionState = PulseMotionState.idle, this.onAction, this.motionOverlay, this.errorMessage});
  final Challenge challenge;
  final PulseMotionState motionState;
  final VoidCallback? onAction;
  final Widget? motionOverlay;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final unavailable = motionState == PulseMotionState.unavailable || motionState == PulseMotionState.error;
    final completed = motionState == PulseMotionState.completed;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;

    return PulseMotionBoundary(
      state: motionState,
      overlay: motionOverlay,
      child: PulseHeroCard(
        onTap: unavailable || completed ? null : onAction,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text('today’s challenge', style: AppTypography.label.copyWith(color: secondary)),
            ),
            const SizedBox(width: PulseSpace.md),
            Text('${challenge.xpReward} XP', style: AppTypography.label.copyWith(color: PulseColors.accent)),
          ]),
          const SizedBox(height: PulseSpace.lg),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: PulseSpace.md, vertical: PulseSpace.sm),
            decoration: BoxDecoration(color: PulseColors.accentTint, borderRadius: BorderRadius.circular(PulseRadius.pill)),
            child: Text(challenge.category.name, style: AppTypography.metadata.copyWith(color: PulseColors.accent, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: PulseSpace.xxl),
          Text(challenge.title, style: AppTypography.headline),
          const SizedBox(height: PulseSpace.md),
          Text(challenge.description, style: AppTypography.body.copyWith(color: secondary)),
          const SizedBox(height: PulseSpace.xl),
          Wrap(
            spacing: PulseSpace.lg,
            runSpacing: PulseSpace.sm,
            children: [
              _Meta(icon: Icons.schedule_rounded, label: '${challenge.estimatedMinutes} min'),
              _Meta(icon: Icons.bolt_rounded, label: challenge.difficulty.name),
              if (challenge.estimatedCost != null) _Meta(icon: Icons.payments_outlined, label: 'about ${challenge.estimatedCost!.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: PulseSpace.xxl),
          if (errorMessage != null) ...[
            Text(errorMessage!, style: AppTypography.metadata.copyWith(color: PulseColors.error)),
            const SizedBox(height: PulseSpace.md),
          ],
          PulseButton(
            label: completed ? 'completed' : 'do today’s challenge',
            onPressed: unavailable || completed ? null : onAction,
            loading: motionState == PulseMotionState.loading,
            expand: true,
            variant: completed ? PulseButtonVariant.secondary : PulseButtonVariant.primary,
            icon: completed ? Icons.check_rounded : Icons.arrow_forward_rounded,
          ),
        ]),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: PulseSpace.sm),
          Text(label, style: AppTypography.metadata),
        ]),
      );
}
