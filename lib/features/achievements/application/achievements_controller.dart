import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/database/repositories.dart';
import '../../../core/motion/pulse_events.dart';
import '../../../models/achievement_model.dart';
import '../../../models/user_model.dart';
import '../data/achievement_definitions.dart';

final achievementsControllerProvider = AsyncNotifierProvider<AchievementsController, AchievementsViewData>(AchievementsController.new);

class AchievementProgress {
  const AchievementProgress({required this.current, required this.target});
  final int current;
  final int target;
}

class AchievementItem {
  const AchievementItem({required this.definition, required this.unlocked, this.unlockedAt, this.progress});
  final AchievementDefinition definition;
  final bool unlocked;
  final DateTime? unlockedAt;
  final AchievementProgress? progress;

  bool get milestone => definition.threshold > 0 && unlocked;
}

class AchievementsViewData {
  const AchievementsViewData({required this.user, required this.items, required this.newlyUnlockedIds});
  final UserModel user;
  final List<AchievementItem> items;
  final Set<String> newlyUnlockedIds;

  List<AchievementItem> get unlocked => items.where((item) => item.unlocked).toList(growable: false);
  List<AchievementItem> get locked => items.where((item) => !item.unlocked).toList(growable: false);
}

class AchievementsController extends AsyncNotifier<AchievementsViewData> {
  @override
  Future<AchievementsViewData> build() => _load();

  Future<AchievementsViewData> _load({Set<String> newlyUnlockedIds = const <String>{}}) async {
    final auth = await ref.read(authServiceProvider).authStateChanges.first;
    final uid = auth?.uid;
    if (uid == null) throw StateError('not authenticated');

    final user = await ref.read(userRepositoryProvider).getUserModel(uid);
    if (user == null) throw StateError('profile unavailable');

    final records = await ref.read(achievementRepositoryProvider).getUnlockedRecords(uid);
    final recordById = {for (final record in records) record.achievementId: record};
    final items = achievementDefinitions.where((definition) => definition.active).map((definition) {
      final record = recordById[definition.id];
      return AchievementItem(
        definition: definition,
        unlocked: record != null || user.unlockedAchievements.contains(definition.id),
        unlockedAt: record?.unlockedAt,
        progress: _progressFor(definition, user),
      );
    }).toList(growable: false);

    return AchievementsViewData(user: user, items: items, newlyUnlockedIds: newlyUnlockedIds);
  }

  AchievementProgress? _progressFor(AchievementDefinition definition, UserModel user) {
    final current = switch (definition.type) {
      AchievementType.streak => user.currentStreak,
      AchievementType.activityCount => user.totalActivities,
      AchievementType.categoryCount => user.completedCategories.length,
      AchievementType.special => null,
    };
    if (current == null || definition.threshold <= 0) return null;
    return AchievementProgress(current: current.clamp(0, definition.threshold), target: definition.threshold);
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load());
  }

  void applyAchievementUnlocked(AchievementUnlockedEvent event) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(AchievementsViewData(user: current.user, items: current.items, newlyUnlockedIds: {...current.newlyUnlockedIds, event.achievementId}));
  }
}
