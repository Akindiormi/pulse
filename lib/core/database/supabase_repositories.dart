import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/activity_model.dart';
import '../../models/achievement_model.dart';
import '../../models/challenge_model.dart';
import '../../models/user_model.dart';
import 'repositories.dart';

class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository(this.supabase);
  final SupabaseClient supabase;

  @override
  Future<void> createOrUpdateUser({required String uid, String? displayName, String? photoUrl}) async {
    await supabase.from('profiles').upsert({
      'id': uid,
      if (displayName != null) 'display_name': displayName,
      if (photoUrl != null) 'photo_url': photoUrl,
    });
  }

  @override
  Future<void> updateProfileFields({required String uid, required Map<String, dynamic> fields}) async {
    final update = UserProfileUpdate(fields).toFirestore();
    await supabase.from('profiles').update(_toSnakeCase(update)).eq('id', uid);
  }

  @override
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final row = await supabase.from('profiles').select().eq('id', uid).maybeSingle();
    return row == null ? null : _profileToModelMap(row);
  }

  @override
  Future<UserModel?> getUserModel(String uid) async {
    final data = await getUser(uid);
    return data == null ? null : UserModel.fromMap(uid, data);
  }

  @override
  Future<void> updatePreferences({required String uid, required Map<String, dynamic> preferences}) async {
    await supabase.from('profiles').update({'notification_preferences': preferences}).eq('id', uid);
  }

  Map<String, dynamic> _profileToModelMap(Map<String, dynamic> row) => {
        'username': row['username'],
        'displayName': row['display_name'],
        'photoUrl': row['photo_url'],
        'createdAt': row['created_at'],
        'totalActivities': row['total_activities'],
        'currentStreak': row['current_streak'],
        'longestStreak': row['longest_streak'],
        'xp': row['xp'],
        'level': row['level'],
        'lastActivityDate': row['last_activity_date'],
        'completedCategories': row['completed_categories'],
        'unlockedAchievements': row['unlocked_achievements'],
      };

  Map<String, dynamic> _toSnakeCase(Map<String, dynamic> fields) => {
        for (final entry in fields.entries) _snakeKey(entry.key): entry.value,
      };

  String _snakeKey(String key) => switch (key) {
        'displayName' => 'display_name',
        'photoUrl' => 'photo_url',
        'timezone' => 'timezone',
        'notificationPreferences' => 'notification_preferences',
        _ => key,
      };
}

class SupabaseChallengeRepository implements ChallengeRepository {
  SupabaseChallengeRepository(this.supabase);
  final SupabaseClient supabase;

  @override
  Future<Map<String, dynamic>?> getDailyAssignment({required String uid, required String date}) async {
    final row = await supabase.from('daily_challenges').select().eq('user_id', uid).eq('date', date).maybeSingle();
    if (row == null) return null;
    return {
      'challengeId': row['challenge_id'],
      'date': row['date'],
      'assignedAt': row['assigned_at'],
      'completedAt': row['completed_at'],
      'completed': row['completed'],
    };
  }

  @override
  Future<Map<String, dynamic>?> getChallenge(String challengeId) async {
    final row = await supabase.from('challenges').select().eq('id', challengeId).maybeSingle();
    return row == null ? null : _challengeToModelMap(row);
  }

  @override
  Future<List<Challenge>> getActiveChallenges() async {
    final rows = await supabase.from('challenges').select().eq('active', true).order('id');
    return rows.map((row) => Challenge.fromMap(row['id'] as String, _challengeToModelMap(row))).toList(growable: false);
  }

  Map<String, dynamic> _challengeToModelMap(Map<String, dynamic> row) => {
        'title': row['title'],
        'description': row['description'],
        'category': row['category'],
        'difficulty': row['difficulty'],
        'xpReward': row['xp_reward'],
        'estimatedMinutes': row['estimated_minutes'],
        'estimatedCost': row['estimated_cost'],
        'active': row['active'],
        'createdAt': row['created_at'],
      };
}

class SupabaseActivityRepository implements ActivityRepository {
  SupabaseActivityRepository(this.supabase);
  final SupabaseClient supabase;

  @override
  Future<bool> isCompleted({required String uid, required String activityId}) async => (await supabase.from('activities').select('id').eq('user_id', uid).eq('id', activityId).maybeSingle()) != null;

  @override
  Future<List<ActivityModel>> getActivities(String uid) async {
    final rows = await supabase.from('activities').select().eq('user_id', uid).order('completed_at', ascending: false);
    return rows.map((row) => ActivityModel.fromMap(row['id'] as String, {
          'userId': row['user_id'],
          'challengeId': row['challenge_id'],
          'date': row['date'],
          'xpAwarded': row['xp_awarded'],
          'completedAt': row['completed_at'],
          'category': row['category'],
        })).toList(growable: false);
  }

  @override
  Future<Set<String>> getCompletedCategories(String uid) async {
    final rows = await supabase.from('activities').select('category').eq('user_id', uid);
    return rows.map((row) => row['category']).whereType<String>().toSet();
  }
}

class SupabaseAchievementRepository implements AchievementRepository {
  SupabaseAchievementRepository(this.supabase);

  final SupabaseClient supabase;

  @override
  Future<Set<String>> getUnlockedIds(String uid) async {
    final rows = await supabase.from('achievements').select('achievement_id').eq('user_id', uid);
    return rows.map((row) => row['achievement_id']).whereType<String>().toSet();
  }

  @override
  Future<List<AchievementRecord>> getUnlockedRecords(String uid) async {
    final rows = await supabase.from('achievements').select().eq('user_id', uid);
    return rows.map((row) => AchievementRecord.fromMap(row['achievement_id'] as String, {'achievementId': row['achievement_id'], 'unlockedAt': row['unlocked_at']})).toList(growable: false);
  }
}
