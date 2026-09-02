import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/pulse_tokens.dart';
import '../../../core/motion/pulse_motion_policy.dart';
import '../../../core/motion/pulse_motion_state.dart';
import '../../../core/widgets/pulse_card.dart';
import '../../../core/widgets/pulse_states.dart';
import '../../../models/user_model.dart';
import '../../../services/xp_service.dart';
import '../application/achievements_controller.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(achievementsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('achievements'), centerTitle: false),
      body: state.when(
        loading: () => const _Loading(),
        error: (_, __) => PulseErrorState(message: 'we couldn’t load your achievements. please try again.', onRetry: () => ref.read(achievementsControllerProvider.notifier).retry()),
        data: (data) => _Collection(data: data, onRefresh: () => ref.read(achievementsControllerProvider.notifier).retry()),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(PulseSpace.lg), children: const [PulseCardLoading(height: 150), SizedBox(height: PulseSpace.lg), PulseCardLoading(height: 170), SizedBox(height: PulseSpace.md), PulseCardLoading(height: 170)]);
}

class _Collection extends StatelessWidget {
  const _Collection({required this.data, required this.onRefresh});
  final AchievementsViewData data;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    final progress = XPService.progress(data.user.xp);
    final nextXp = XPService.nextLevelXP(data.user.xp);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(PulseSpace.lg, PulseSpace.md, PulseSpace.lg, PulseSpace.xxxl), children: [
        _ProgressHeader(user: data.user, progress: progress, nextLevelXP: nextXp),
        const SizedBox(height: PulseSpace.xxl),
        _SectionTitle(title: 'your collection', count: data.items.length),
        const SizedBox(height: PulseSpace.md),
        if (data.items.isEmpty)
          const PulseEmptyState(title: 'your collection starts here.', message: 'complete your first challenge to unlock your first badge.')
        else ...[
          if (data.unlocked.isNotEmpty) ...[_SectionTitle(title: 'unlocked', count: data.unlocked.length), const SizedBox(height: PulseSpace.md), _Grid(items: data.unlocked, newlyUnlockedIds: data.newlyUnlockedIds), const SizedBox(height: PulseSpace.xxl)],
          _SectionTitle(title: 'locked', count: data.locked.length),
          const SizedBox(height: PulseSpace.md),
          if (data.locked.isEmpty) const PulseEmptyState(title: 'collection complete.', message: 'you unlocked every active achievement. keep going.') else _Grid(items: data.locked, newlyUnlockedIds: data.newlyUnlockedIds),
        ],
      ]),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.user, required this.progress, required this.nextLevelXP});
  final UserModel user;
  final double progress;
  final int nextLevelXP;
  @override
  Widget build(BuildContext context) => PulseCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text('level ${user.level}', style: AppTypography.title)), Text('${user.xp} XP', style: AppTypography.metadata.copyWith(fontWeight: FontWeight.w700))]),
    const SizedBox(height: PulseSpace.md),
    Semantics(label: '${user.xp} XP toward level ${user.level + 1}', value: '${(progress * 100).round()} percent', child: ClipRRect(borderRadius: BorderRadius.circular(PulseRadius.small), child: LinearProgressIndicator(value: progress, minHeight: 8))),
    const SizedBox(height: PulseSpace.sm),
    Text('$nextLevelXP XP target for next level', style: AppTypography.metadata),
    const SizedBox(height: PulseSpace.lg),
    Row(children: [
      Expanded(child: _Metric(label: 'current streak', value: '${user.currentStreak} days', state: user.currentStreak > 0 ? PulseStreakMotionState.active : PulseStreakMotionState.inactive)),
      const SizedBox(width: PulseSpace.sm),
      Expanded(child: _Metric(label: 'longest', value: '${user.longestStreak} days', state: user.longestStreak > 0 ? PulseStreakMotionState.milestone : PulseStreakMotionState.inactive)),
      const SizedBox(width: PulseSpace.sm),
      Expanded(child: _Metric(label: 'completed', value: '${user.totalActivities}', state: PulseProgressMotionState.unchanged)),
    ]),
  ]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.state});
  final String label, value;
  final Object state;
  @override
  Widget build(BuildContext context) => Semantics(label: '$label: $value', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(label, style: AppTypography.metadata)]));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});
  final String title;
  final int count;
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: AppTypography.title)), Text('$count', style: AppTypography.metadata)]);
}

class _Grid extends StatelessWidget {
  const _Grid({required this.items, required this.newlyUnlockedIds});
  final List<AchievementItem> items;
  final Set<String> newlyUnlockedIds;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final columns = constraints.maxWidth >= 560 ? 3 : 2;
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: PulseSpace.md, mainAxisSpacing: PulseSpace.md, childAspectRatio: .86), itemBuilder: (_, index) => _AchievementTile(item: items[index], newlyUnlocked: newlyUnlockedIds.contains(items[index].definition.id)));
  });
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.item, required this.newlyUnlocked});
  final AchievementItem item;
  final bool newlyUnlocked;
  @override
  Widget build(BuildContext context) {
    final motion = newlyUnlocked ? PulseAchievementMotionState.newlyUnlocked : item.unlocked ? PulseAchievementMotionState.unlocked : PulseAchievementMotionState.locked;
    return Semantics(button: true, label: '${item.definition.name}, ${item.unlocked ? 'unlocked' : 'locked'}: ${item.definition.description}', child: InkWell(
      borderRadius: BorderRadius.circular(PulseRadius.large),
      onTap: () => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => _AchievementDetail(item: item, newlyUnlocked: newlyUnlocked)),
      child: AnimatedContainer(duration: PulseMotionPolicy.duration(context, const Duration(milliseconds: 220)), padding: const EdgeInsets.all(PulseSpace.lg), decoration: BoxDecoration(color: item.unlocked ? PulseColors.accentTint : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(PulseRadius.large)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _BadgeIcon(unlocked: item.unlocked, motion: motion), const Spacer(), Text(item.definition.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: PulseSpace.xs), Text(item.unlocked ? 'unlocked' : 'locked', style: AppTypography.metadata),
        if (!item.unlocked && item.progress != null) ...[const SizedBox(height: PulseSpace.sm), LinearProgressIndicator(value: item.progress!.current / item.progress!.target, minHeight: 4), const SizedBox(height: 4), Text('${item.progress!.current} / ${item.progress!.target}', style: AppTypography.metadata)],
      ])),
    ));
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.unlocked, required this.motion});
  final bool unlocked;
  final PulseAchievementMotionState motion;
  @override
  Widget build(BuildContext context) => Semantics(label: motion.name, child: Container(width: 54, height: 54, decoration: BoxDecoration(shape: BoxShape.circle, color: unlocked ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surface.withValues(alpha: .55)), child: Icon(unlocked ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded, color: unlocked ? PulseColors.accent : Theme.of(context).colorScheme.onSurfaceVariant, size: 28)));
}

class _AchievementDetail extends StatelessWidget {
  const _AchievementDetail({required this.item, required this.newlyUnlocked});
  final AchievementItem item;
  final bool newlyUnlocked;
  @override
  Widget build(BuildContext context) {
    final date = item.unlockedAt;
    return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(PulseSpace.xl, PulseSpace.md, PulseSpace.xl, PulseSpace.xxxl), child: Semantics(label: '${item.definition.name} details, ${item.unlocked ? 'unlocked' : 'locked'}', child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(item.unlocked ? (newlyUnlocked ? 'newly unlocked' : 'achievement unlocked') : 'locked', style: AppTypography.metadata.copyWith(color: PulseColors.accent, fontWeight: FontWeight.w700)), const SizedBox(height: PulseSpace.md), Text(item.definition.name, style: AppTypography.headline), const SizedBox(height: PulseSpace.sm), Text(item.definition.description, style: AppTypography.body), const SizedBox(height: PulseSpace.lg),
      if (item.progress != null && !item.unlocked) ...[Text('${item.progress!.current} / ${item.progress!.target}', style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: PulseSpace.sm), LinearProgressIndicator(value: item.progress!.current / item.progress!.target), const SizedBox(height: PulseSpace.lg)],
      if (item.unlocked && date != null) Text('unlocked on ${_date(date)}', style: AppTypography.metadata), const SizedBox(height: PulseSpace.md), Text('+${item.definition.xpReward} XP', style: AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
    ]))));
  }
  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
