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
    return PulseMotionBoundary(
      state: motionState,
      overlay: motionOverlay,
      child: PulseHeroCard(
        onTap: unavailable ? null : onAction,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: PulseSpace.md, vertical: PulseSpace.sm), decoration: BoxDecoration(color: PulseColors.accentTint, borderRadius: BorderRadius.circular(PulseRadius.pill)), child: Text(challenge.category.name, style: AppTypography.metadata.copyWith(color: PulseColors.accent, fontWeight: FontWeight.w700))),
            const Spacer(),
            Text('${challenge.xpReward} XP', style: AppTypography.label.copyWith(color: PulseColors.accent)),
          ]),
          const Spacer(),
          Text(challenge.title, style: AppTypography.headline),
          const SizedBox(height: PulseSpace.md),
          Text(challenge.description, style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: PulseSpace.lg),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: PulseSpace.sm),
            Text('${challenge.estimatedMinutes} min', style: AppTypography.metadata),
            const SizedBox(width: PulseSpace.lg),
            Text(challenge.difficulty.name, style: AppTypography.metadata),
          ]),
          const SizedBox(height: PulseSpace.xl),
          if (errorMessage != null) ...[
            Text(errorMessage!, style: AppTypography.metadata.copyWith(color: PulseColors.error)),
            const SizedBox(height: PulseSpace.md),
          ],
          PulseButton(label: completed ? 'completed' : 'do today\'s challenge', onPressed: unavailable || completed ? null : onAction, loading: motionState == PulseMotionState.loading, expand: true, variant: completed ? PulseButtonVariant.secondary : PulseButtonVariant.primary, icon: completed ? Icons.check_rounded : Icons.arrow_forward_rounded),
        ]),
      ),
    );
  }
}
