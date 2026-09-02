import 'package:flutter/material.dart';
import '../../models/achievement_model.dart';
import '../design/pulse_tokens.dart';
import '../motion/pulse_motion_state.dart';
import '../theme/app_theme.dart';

class PulseAchievementBadge extends StatelessWidget {
  const PulseAchievementBadge({super.key, required this.definition, this.unlocked = false, this.newlyUnlocked = false, this.progress, this.motionState});
  final AchievementDefinition definition;
  final bool unlocked;
  final bool newlyUnlocked;
  final int? progress;
  final PulseAchievementMotionState? motionState;

  @override
  Widget build(BuildContext context) {
    final state = motionState ?? (newlyUnlocked ? PulseAchievementMotionState.newlyUnlocked : unlocked ? PulseAchievementMotionState.unlocked : PulseAchievementMotionState.locked);
    final active = state != PulseAchievementMotionState.locked;
    final accent = active ? PulseColors.accent : Theme.of(context).colorScheme.onSurfaceVariant;
    final threshold = definition.threshold;
    return Semantics(
      label: '${definition.name}, ${active ? 'unlocked' : 'locked'}',
      child: Container(
        padding: const EdgeInsets.all(PulseSpace.lg),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(PulseRadius.large)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: accent.withValues(alpha: active ? 0.14 : 0.07), borderRadius: BorderRadius.circular(PulseRadius.medium)), child: Icon(active ? Icons.workspace_premium_rounded : Icons.lock_rounded, color: accent)),
          const SizedBox(width: PulseSpace.lg),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(definition.name, style: AppTypography.title)), if (state == PulseAchievementMotionState.newlyUnlocked) const _NewBadge()]),
            const SizedBox(height: PulseSpace.xs),
            Text(definition.description, style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (progress != null) ...[
              const SizedBox(height: PulseSpace.md),
              Text('${progress!.clamp(0, threshold)} / $threshold', style: AppTypography.metadata),
            ],
          ])),
        ]),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: PulseSpace.sm, vertical: PulseSpace.xs), decoration: BoxDecoration(color: PulseColors.accentTint, borderRadius: BorderRadius.circular(PulseRadius.pill)), child: Text('new', style: AppTypography.metadata.copyWith(color: PulseColors.accent, fontWeight: FontWeight.w700)));
}
