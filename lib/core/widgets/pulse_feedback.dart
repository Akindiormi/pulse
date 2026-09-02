import 'package:flutter/material.dart';
import '../design/pulse_tokens.dart';
import '../motion/pulse_celebration.dart';
import '../motion/pulse_motion_policy.dart';
import '../motion/pulse_motion_state.dart';

class PulseCompletionSurface extends StatelessWidget {
  const PulseCompletionSurface({
    super.key,
    required this.event,
    this.xpAwarded = 0,
    this.streak,
    this.achievementIds = const <String>[],
    this.previousLevel,
    this.newLevel,
    this.motionOverlay,
  });

  final PulseCelebrationEvent event;
  final int xpAwarded;
  final int? streak;
  final List<String> achievementIds;
  final int? previousLevel;
  final int? newLevel;
  final Widget? motionOverlay;

  @override
  Widget build(BuildContext context) {
    final levelChanged = previousLevel != null && newLevel != null && newLevel != previousLevel;
    final lines = <String>[
      if (xpAwarded > 0) '+$xpAwarded XP',
      if (streak != null) 'streak: $streak day${streak == 1 ? '' : 's'}',
      if (achievementIds.isNotEmpty) 'achievement unlocked: ${achievementIds.map(_label).join(', ')}',
      if (levelChanged) 'level $previousLevel → level $newLevel',
    ];

    final overlay = motionOverlay ??
        (event == PulseCelebrationEvent.completion
            ? PulseCompletionCelebration(hasAchievement: achievementIds.isNotEmpty, leveledUp: levelChanged)
            : null);

    return PulseFeedbackSurface(
      semanticLabel: 'challenge completion feedback',
      icon: Icons.check_rounded,
      title: levelChanged ? 'level up.' : 'nice. you did it.',
      detail: lines.isEmpty ? 'challenge completed' : lines.join('\n'),
      overlay: overlay,
    );
  }

  String _label(String value) => value
      .toLowerCase()
      .split('_')
      .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class PulseLevelUpSurface extends StatelessWidget {
  const PulseLevelUpSurface({super.key, required this.level, this.motionOverlay});
  final int level;
  final Widget? motionOverlay;

  @override
  Widget build(BuildContext context) => PulseFeedbackSurface(
        semanticLabel: 'level up feedback, level $level',
        icon: Icons.auto_awesome_rounded,
        title: 'level up.',
        detail: 'you reached level $level',
        overlay: motionOverlay ?? const PulseCompletionCelebration(leveledUp: true),
      );
}

class PulseFeedbackSurface extends StatelessWidget {
  const PulseFeedbackSurface({super.key, required this.semanticLabel, required this.icon, required this.title, required this.detail, this.overlay});
  final String semanticLabel;
  final IconData icon;
  final String title;
  final String detail;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        liveRegion: true,
        child: Stack(children: [
          AnimatedContainer(
            duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 260)),
            width: double.infinity,
            padding: const EdgeInsets.all(PulseSpace.xxxl),
            decoration: BoxDecoration(color: PulseColors.accentTint, borderRadius: BorderRadius.circular(PulseRadius.hero)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: PulseColors.accent, size: 32),
              const SizedBox(height: PulseSpace.xl),
              Text(title, style: AppTypography.headline),
              const SizedBox(height: PulseSpace.sm),
              Text(detail, style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
          if (overlay != null && !PulseMotionPolicy.isReducedMotion(context)) Positioned.fill(child: IgnorePointer(child: overlay!)),
        ]),
      );
}
