import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/activity_model.dart';
import '../../models/achievement_model.dart';
import '../../models/calendar_event_model.dart';
import '../../models/challenge_model.dart';
import '../../models/milestone_model.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import 'repositories.dart';

class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository(this.supabase);
  final SupabaseClient supabase;
  @override Future<void> createOrUpdateUser({required String uid, String? displayName, String? photoUrl}) async => await supabase.from('profiles').upsert({'id': uid, if (displayName != null) 'display_name': displayName, if (photoUrl != null) 'photo_url': photoUrl});
  @override Future<void> updateProfileFields({required String uid, required Map<String, dynamic> fields}) async => await supabase.from('profiles').update(_toSnakeCase(UserProfileUpdate(fields).toFirestore())).eq('id', uid);
  @override Future<Map<String, dynamic>?> getUser(String uid) async { final row = await supabase.from('profiles').select().eq('id', uid).maybeSingle(); return row == null ? null : _profileToModelMap(row); }
  @override Future<UserModel?> getUserModel(String uid) async { final data = await getUser(uid); return data == null ? null : UserModel.fromMap(uid, data); }
  @override Future<void> updatePreferences({required String uid, required Map<String, dynamic> preferences}) async => await supabase.from('profiles').update({'notification_preferences': preferences}).eq('id', uid);
  Map<String, dynamic> _profileToModelMap(Map<String, dynamic> row) => {'username': row['username'], 'displayName': row['display_name'], 'photoUrl': row['photo_url'], 'timezone': row['timezone'], 'createdAt': row['created_at'], 'totalActivities': row['total_activities'], 'currentStreak': row['current_streak'], 'longestStreak': row['longest_streak'], 'xp': row['xp'], 'level': row['level'], 'lastActivityDate': row['last_activity_date'], 'completedCategories': row['completed_categories'], 'unlockedAchievements': row['unlocked_achievements']};
  Map<String, dynamic> _toSnakeCase(Map<String, dynamic> fields) => {for (final entry in fields.entries) _snakeKey(entry.key): entry.value};
  String _snakeKey(String key) => switch (key) {'displayName' => 'display_name', 'photoUrl' => 'photo_url', 'timezone' => 'timezone', 'notificationPreferences' => 'notification_preferences', _ => key};
}

class SupabaseChallengeRepository implements ChallengeRepository {
  SupabaseChallengeRepository(this.supabase); final SupabaseClient supabase;
  @override Future<Map<String, dynamic>?> getDailyAssignment({required String uid, required String date}) async { final row = await supabase.from('daily_challenges').select().eq('user_id', uid).eq('date', date).maybeSingle(); if (row == null) return null; return {'challengeId': row['challenge_id'], 'date': row['date'], 'assignedAt': row['assigned_at'], 'completedAt': row['completed_at'], 'completed': row['completed']}; }
  @override Future<Map<String, dynamic>?> getChallenge(String challengeId) async { final row = await supabase.from('challenges').select().eq('id', challengeId).maybeSingle(); return row == null ? null : _challengeToModelMap(row); }
  @override Future<List<Challenge>> getActiveChallenges() async { final rows = await supabase.from('challenges').select().eq('active', true).order('id'); return rows.map((row) => Challenge.fromMap(row['id'] as String, _challengeToModelMap(row))).toList(growable: false); }
  Map<String, dynamic> _challengeToModelMap(Map<String, dynamic> row) => {'title': row['title'], 'description': row['description'], 'category': row['category'], 'difficulty': row['difficulty'], 'xpReward': row['xp_reward'], 'estimatedMinutes': row['estimated_minutes'], 'estimatedCost': row['estimated_cost'], 'active': row['active'], 'createdAt': row['created_at']};
}

class SupabaseActivityRepository implements ActivityRepository {
  SupabaseActivityRepository(this.supabase); final SupabaseClient supabase;
  @override Future<bool> isCompleted({required String uid, required String activityId}) async => (await supabase.from('activities').select('id').eq('user_id', uid).eq('id', activityId).maybeSingle()) != null;
  @override Future<List<ActivityModel>> getActivities(String uid) async { final rows = await supabase.from('activities').select().eq('user_id', uid).order('completed_at', ascending: false); return rows.map((row) => ActivityModel.fromMap(row['id'] as String, {'userId': row['user_id'], 'challengeId': row['challenge_id'], 'date': row['date'], 'xpAwarded': row['xp_awarded'], 'completedAt': row['completed_at'], 'category': row['category']})).toList(growable: false); }
  @override Future<Set<String>> getCompletedCategories(String uid) async { final rows = await supabase.from('activities').select('category').eq('user_id', uid); return rows.map((row) => row['category']).whereType<String>().toSet(); }
}

class SupabaseTaskRepository implements TaskRepository {
  SupabaseTaskRepository(this.supabase); final SupabaseClient supabase;
  @override Future<List<Task>> getTasks({required String uid}) async { final rows = await supabase.from('tasks').select().eq('user_id', uid).order('due_date', nullsFirst: false).order('due_time', nullsFirst: false).order('created_at'); return rows.map((row) => Task.fromMap(row['id'] as String, row)).toList(growable: false); }
  @override Future<List<Task>> getProjectTasks({required String uid, required String projectId}) async { final rows = await supabase.from('tasks').select().eq('user_id', uid).eq('project_id', projectId).order('due_date', nullsFirst: false).order('created_at'); return rows.map((row) => Task.fromMap(row['id'] as String, row)).toList(growable: false); }
  @override Future<Task> createTask({required String uid, required String title, DateTime? dueDate, String? dueTime, String? projectId, String? milestoneId, int priority = 0}) async { final row = await supabase.from('tasks').insert({'user_id': uid, 'title': title.trim(), if (dueDate != null) 'due_date': dueDate.toIso8601String().split('T').first, if (dueTime != null) 'due_time': dueTime, if (projectId != null) 'project_id': projectId, if (milestoneId != null) 'milestone_id': milestoneId, 'priority': priority}).select().single(); return Task.fromMap(row['id'] as String, row); }
  @override Future<Task> updateTask({required String taskId, String? title, DateTime? dueDate, String? dueTime, String? projectId, String? milestoneId, int? priority}) async { final values = <String, dynamic>{if (title != null) 'title': title.trim(), if (dueDate != null) 'due_date': dueDate.toIso8601String().split('T').first, if (dueTime != null) 'due_time': dueTime, if (projectId != null) 'project_id': projectId, if (milestoneId != null) 'milestone_id': milestoneId, if (priority != null) 'priority': priority}; final row = await supabase.from('tasks').update(values).eq('id', taskId).select().single(); return Task.fromMap(row['id'] as String, row); }
  @override Future<void> deleteTask({required String taskId}) async => await supabase.from('tasks').delete().eq('id', taskId);
  @override Future<TaskCompletionResult> completeTask({required String taskId}) async { final result = await supabase.rpc('complete_task', params: {'p_task_id': taskId}); return TaskCompletionResult.fromMap(Map<String, dynamic>.from(result as Map)); }
}

class SupabaseProjectRepository implements ProjectRepository {
  SupabaseProjectRepository(this.supabase); final SupabaseClient supabase;
  @override Future<List<Project>> getProjects({required String uid}) async { final rows = await supabase.from('projects').select().eq('user_id', uid).order('updated_at', ascending: false); return rows.map((row) => Project.fromMap(row['id'] as String, row)).toList(growable: false); }
  @override Future<Project?> getProject({required String uid, required String projectId}) async { final row = await supabase.from('projects').select().eq('id', projectId).eq('user_id', uid).maybeSingle(); return row == null ? null : Project.fromMap(row['id'] as String, row); }
  @override Future<Project> createProject({required String uid, required String name, String? description}) async { final row = await supabase.from('projects').insert({'user_id': uid, 'name': name.trim(), if (description != null && description.trim().isNotEmpty) 'description': description.trim()}).select().single(); return Project.fromMap(row['id'] as String, row); }
  @override Future<Project> updateProject({required String projectId, String? name, String? description, ProjectStatus? status}) async { final values = <String, dynamic>{if (name != null) 'name': name.trim(), if (description != null) 'description': description.trim(), if (status != null) 'status': status.value}; final row = values.isEmpty ? await supabase.from('projects').select().eq('id', projectId).single() : await supabase.from('projects').update(values).eq('id', projectId).select().single(); return Project.fromMap(row['id'] as String, row); }
  @override Future<void> deleteProject({required String projectId}) async => await supabase.from('projects').delete().eq('id', projectId);
}

class SupabaseMilestoneRepository implements MilestoneRepository {
  SupabaseMilestoneRepository(this.supabase); final SupabaseClient supabase;
  @override Future<List<Milestone>> getMilestones({required String uid, required String projectId}) async { final rows = await supabase.from('milestones').select().eq('user_id', uid).eq('project_id', projectId).order('due_date', nullsFirst: false).order('created_at'); return rows.map((row) => Milestone.fromMap(row['id'] as String, row)).toList(growable: false); }
  @override Future<Milestone> createMilestone({required String uid, required String projectId, required String name, String? description, DateTime? dueDate}) async { final row = await supabase.from('milestones').insert({'user_id': uid, 'project_id': projectId, 'name': name.trim(), if (description != null && description.trim().isNotEmpty) 'description': description.trim(), if (dueDate != null) 'due_date': dueDate.toIso8601String().split('T').first}).select().single(); return Milestone.fromMap(row['id'] as String, row); }
  @override Future<Milestone> updateMilestone({required String milestoneId, String? name, String? description, DateTime? dueDate, MilestoneStatus? status}) async { final values = <String, dynamic>{if (name != null) 'name': name.trim(), if (description != null) 'description': description.trim(), if (dueDate != null) 'due_date': dueDate.toIso8601String().split('T').first, if (status != null) 'status': status.value}; final row = await supabase.from('milestones').update(values).eq('id', milestoneId).select().single(); return Milestone.fromMap(row['id'] as String, row); }
  @override Future<void> deleteMilestone({required String milestoneId}) async => await supabase.from('milestones').delete().eq('id', milestoneId);
}

class SupabaseCalendarRepository implements CalendarRepository {
  SupabaseCalendarRepository(this.supabase);
  final SupabaseClient supabase;

  @override
  Future<List<CalendarEvent>> getEvents({required String uid, required DateTime rangeStart, required DateTime rangeEnd}) async {
    if (!rangeEnd.isAfter(rangeStart)) throw ArgumentError('rangeEnd must be after rangeStart');
    final rows = await supabase
        .from('calendar_events')
        .select('*, task_calendar_events(task_id)')
        .eq('user_id', uid)
        .lte('starts_at', rangeEnd.toUtc().toIso8601String())
        .order('starts_at');
    return rows.map((row) {
      final links = (row['task_calendar_events'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map((link) => link['task_id'])
          .whereType<String>()
          .toList(growable: false);
      return CalendarEvent.fromMap(row['id'] as String, {...row, 'task_ids': links});
    }).where((event) => event.isRecurring || event.endsAt.isAfter(rangeStart)).toList(growable: false);
  }

  @override
  Future<CalendarEvent> createEvent({required String uid, required String title, String? description, required DateTime startsAt, required DateTime endsAt, bool allDay = false, required String timezone, String? recurrenceRule, String? taskId}) async {
    if (!endsAt.isAfter(startsAt)) throw ArgumentError('endsAt must be after startsAt');
    final row = await supabase.from('calendar_events').insert({'user_id': uid, 'title': title.trim(), if (description != null && description.trim().isNotEmpty) 'description': description.trim(), 'starts_at': startsAt.toUtc().toIso8601String(), 'ends_at': endsAt.toUtc().toIso8601String(), 'all_day': allDay, 'timezone': timezone, if (recurrenceRule != null && recurrenceRule.trim().isNotEmpty) 'recurrence_rule': recurrenceRule.trim()}).select().single();
    final event = CalendarEvent.fromMap(row['id'] as String, row);
    if (taskId != null) await linkTask(taskId: taskId, eventId: event.id);
    return taskId == null ? event : event.copyWith(taskIds: <String>[taskId]);
  }

  @override
  Future<CalendarEvent> updateEvent({required String eventId, String? title, String? description, DateTime? startsAt, DateTime? endsAt, bool? allDay, String? timezone, String? recurrenceRule}) async {
    final values = <String, dynamic>{if (title != null) 'title': title.trim(), if (description != null) 'description': description.trim(), if (startsAt != null) 'starts_at': startsAt.toUtc().toIso8601String(), if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(), if (allDay != null) 'all_day': allDay, if (timezone != null) 'timezone': timezone, if (recurrenceRule != null) 'recurrence_rule': recurrenceRule.trim()};
    if (startsAt != null && endsAt != null && !endsAt.isAfter(startsAt)) throw ArgumentError('endsAt must be after startsAt');
    final row = values.isEmpty ? await supabase.from('calendar_events').select('*, task_calendar_events(task_id)').eq('id', eventId).single() : await supabase.from('calendar_events').update(values).eq('id', eventId).select('*, task_calendar_events(task_id)').single();
    final links = (row['task_calendar_events'] as List<dynamic>? ?? const <dynamic>[]).whereType<Map<String, dynamic>>().map((link) => link['task_id']).whereType<String>().toList(growable: false);
    return CalendarEvent.fromMap(row['id'] as String, {...row, 'task_ids': links});
  }

  @override Future<void> deleteEvent({required String eventId}) async => await supabase.from('calendar_events').delete().eq('id', eventId);
  @override Future<void> linkTask({required String taskId, required String eventId}) async => await supabase.from('task_calendar_events').insert({'task_id': taskId, 'calendar_event_id': eventId});
  @override Future<void> unlinkTask({required String taskId, required String eventId}) async => await supabase.from('task_calendar_events').delete().eq('task_id', taskId).eq('calendar_event_id', eventId);
}

class SupabaseAchievementRepository implements AchievementRepository {
  SupabaseAchievementRepository(this.supabase); final SupabaseClient supabase;
  @override Future<Set<String>> getUnlockedIds(String uid) async { final rows = await supabase.from('achievements').select('achievement_id').eq('user_id', uid); return rows.map((row) => row['achievement_id']).whereType<String>().toSet(); }
  @override Future<List<AchievementRecord>> getUnlockedRecords(String uid) async { final rows = await supabase.from('achievements').select().eq('user_id', uid); return rows.map((row) => AchievementRecord.fromMap(row['achievement_id'] as String, {'achievementId': row['achievement_id'], 'unlockedAt': row['unlocked_at']})).toList(growable: false); }
}
