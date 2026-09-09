import '../../models/activity_model.dart';
import '../../models/achievement_model.dart';
import '../../models/challenge_model.dart';
import '../../models/milestone_model.dart';
import '../../models/project_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';

class UserProfileUpdate {
  const UserProfileUpdate(this.fields);
  final Map<String, dynamic> fields;
  static const allowedFields = <String>{'displayName', 'photoUrl', 'timezone', 'notificationPreferences'};
  Map<String, dynamic> toFirestore() {
    if (fields.isEmpty || fields.keys.any((key) => !allowedFields.contains(key))) throw ArgumentError('Profile updates may only change supported profile fields.');
    return Map<String, dynamic>.from(fields);
  }
}

abstract interface class UserRepository {
  Future<void> createOrUpdateUser({required String uid, String? displayName, String? photoUrl});
  Future<void> updateProfileFields({required String uid, required Map<String, dynamic> fields});
  Future<Map<String, dynamic>?> getUser(String uid);
  Future<UserModel?> getUserModel(String uid) async { final data = await getUser(uid); return data == null ? null : UserModel.fromMap(uid, data); }
  Future<void> updatePreferences({required String uid, required Map<String, dynamic> preferences}) async => throw UnimplementedError('User preferences are not implemented by this repository.');
}

abstract interface class ChallengeRepository {
  Future<Map<String, dynamic>?> getDailyAssignment({required String uid, required String date});
  Future<Map<String, dynamic>?> getChallenge(String challengeId);
  Future<List<Challenge>> getActiveChallenges() async => throw UnimplementedError('Active challenge listing is not implemented by this repository.');
}

abstract interface class ActivityRepository {
  Future<bool> isCompleted({required String uid, required String activityId});
  Future<List<ActivityModel>> getActivities(String uid) async => throw UnimplementedError('Activity listing is not implemented by this repository.');
  Future<Set<String>> getCompletedCategories(String uid) async => throw UnimplementedError('Category history is not implemented by this repository.');
}

abstract interface class TaskRepository {
  Future<List<Task>> getTasks({required String uid});
  Future<List<Task>> getProjectTasks({required String uid, required String projectId});
  Future<Task> createTask({required String uid, required String title, DateTime? dueDate, String? dueTime, String? projectId, String? milestoneId, int priority = 0});
  Future<Task> updateTask({required String taskId, String? title, DateTime? dueDate, String? dueTime, String? projectId, String? milestoneId, int? priority});
  Future<void> deleteTask({required String taskId});
  Future<TaskCompletionResult> completeTask({required String taskId});
}

abstract interface class ProjectRepository {
  Future<List<Project>> getProjects({required String uid});
  Future<Project?> getProject({required String uid, required String projectId});
  Future<Project> createProject({required String uid, required String name, String? description});
  Future<Project> updateProject({required String projectId, String? name, String? description, ProjectStatus? status});
  Future<void> deleteProject({required String projectId});
}

abstract interface class MilestoneRepository {
  Future<List<Milestone>> getMilestones({required String uid, required String projectId});
  Future<Milestone> createMilestone({required String uid, required String projectId, required String name, String? description, DateTime? dueDate});
  Future<Milestone> updateMilestone({required String milestoneId, String? name, String? description, DateTime? dueDate, MilestoneStatus? status});
  Future<void> deleteMilestone({required String milestoneId});
}

abstract interface class AchievementRepository {
  Future<Set<String>> getUnlockedIds(String uid);
  Future<List<AchievementRecord>> getUnlockedRecords(String uid) async => throw UnimplementedError('Achievement record listing is not implemented by this repository.');
}
