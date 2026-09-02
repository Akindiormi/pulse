import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../models/achievement_model.dart';
import '../../../models/user_model.dart';

final profileControllerProvider = AsyncNotifierProvider<ProfileController, ProfileViewData>(ProfileController.new);

enum ProfileEditState { idle, editing, saving, saved, error }

class ProfileViewData {
  const ProfileViewData({required this.user, required this.achievements});
  final UserModel user;
  final List<AchievementRecord> achievements;

  int get unlockedAchievementCount => achievements.length;
  List<AchievementRecord> get achievementHighlights => achievements.take(3).toList(growable: false);
}

class ProfileController extends AsyncNotifier<ProfileViewData> {
  ProfileEditState editState = ProfileEditState.idle;
  String? editError;

  @override
  Future<ProfileViewData> build() => _load();

  Future<ProfileViewData> _load() async {
    final auth = await ref.read(authServiceProvider).authStateChanges.first;
    final uid = auth.uid;
    if (uid == null) throw StateError('not authenticated');

    final user = await ref.read(userRepositoryProvider).getUserModel(uid);
    if (user == null) throw StateError('profile unavailable');

    final records = await ref.read(achievementRepositoryProvider).getUnlockedRecords(uid);
    return ProfileViewData(user: user, achievements: records);
  }

  void beginEditing() {
    editError = null;
    editState = ProfileEditState.editing;
  }

  Future<bool> saveDisplayName(String value) async {
    final current = state.valueOrNull;
    if (current == null || editState == ProfileEditState.saving) return false;
    editState = ProfileEditState.saving;
    editError = null;
    final auth = await ref.read(authServiceProvider).authStateChanges.first;
    final uid = auth.uid;
    if (uid == null) {
      editState = ProfileEditState.error;
      editError = 'your session is no longer active. please sign in again.';
      return false;
    }
    try {
      final trimmed = value.trim();
      await ref.read(userRepositoryProvider).updateProfileFields(
        uid: uid,
        fields: <String, dynamic>{'displayName': trimmed.isEmpty ? null : trimmed},
      );
      final refreshed = await _load();
      state = AsyncData(refreshed);
      editState = ProfileEditState.saved;
      return true;
    } catch (_) {
      editState = ProfileEditState.error;
      editError = 'we couldn’t save your profile. please try again.';
      return false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
  }

  Future<void> deleteAccount() async {
    await ref.read(authServiceProvider).deleteAccount();
  }
}
