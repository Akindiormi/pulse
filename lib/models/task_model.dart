class Task {
  const Task({required this.id, required this.userId, required this.title, this.description, this.status = TaskStatus.todo, this.dueDate, this.dueTime, this.projectId, this.milestoneId, this.priority = 0, this.taskSeriesId, this.occurrenceKey, this.firstCompletedAt, this.completedAt, this.createdAt, this.updatedAt});

  final String id;
  final String userId;
  final String title;
  final String? description;
  final TaskStatus status;
  final DateTime? dueDate;
  final String? dueTime;
  final String? projectId;
  final String? milestoneId;
  final int priority;
  final String? taskSeriesId;
  final DateTime? occurrenceKey;
  final DateTime? firstCompletedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCompleted => status == TaskStatus.completed;
  bool get isOpen => status == TaskStatus.todo || status == TaskStatus.inProgress;

  Task copyWith({String? title, String? description, TaskStatus? status, DateTime? dueDate, String? dueTime, String? projectId, String? milestoneId, int? priority, String? taskSeriesId, DateTime? occurrenceKey, DateTime? firstCompletedAt, DateTime? completedAt, bool clearCompletedAt = false, DateTime? updatedAt}) => Task(id: id, userId: userId, title: title ?? this.title, description: description ?? this.description, status: status ?? this.status, dueDate: dueDate ?? this.dueDate, dueTime: dueTime ?? this.dueTime, projectId: projectId ?? this.projectId, milestoneId: milestoneId ?? this.milestoneId, priority: priority ?? this.priority, taskSeriesId: taskSeriesId ?? this.taskSeriesId, occurrenceKey: occurrenceKey ?? this.occurrenceKey, firstCompletedAt: firstCompletedAt ?? this.firstCompletedAt, completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt), createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt);

  factory Task.fromMap(String id, Map<String, dynamic> map) => Task(id: id, userId: map['user_id'] as String? ?? map['userId'] as String, title: map['title'] as String, description: map['description'] as String?, status: TaskStatus.fromValue(map['status'] as String? ?? 'todo'), dueDate: _date(map['due_date'] ?? map['dueDate']), dueTime: map['due_time']?.toString() ?? map['dueTime']?.toString(), projectId: map['project_id'] as String? ?? map['projectId'] as String?, milestoneId: map['milestone_id'] as String? ?? map['milestoneId'] as String?, priority: (map['priority'] as num?)?.toInt() ?? 0, taskSeriesId: map['task_series_id'] as String? ?? map['taskSeriesId'] as String?, occurrenceKey: _date(map['occurrence_key'] ?? map['occurrenceKey']), firstCompletedAt: _date(map['first_completed_at'] ?? map['firstCompletedAt']), completedAt: _date(map['completed_at'] ?? map['completedAt']), createdAt: _date(map['created_at'] ?? map['createdAt']), updatedAt: _date(map['updated_at'] ?? map['updatedAt']));

  static DateTime? _date(Object? value) => value == null ? null : (value is DateTime ? value : DateTime.tryParse(value.toString()));
}

enum TaskStatus {
  todo('todo'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const TaskStatus(this.value);
  final String value;
  static TaskStatus fromValue(String value) => TaskStatus.values.firstWhere((item) => item.value == value, orElse: () => TaskStatus.todo);
}

enum TaskRecurrenceType {
  daily('daily'),
  weekly('weekly'),
  interval('interval');

  const TaskRecurrenceType(this.value);
  final String value;
  static TaskRecurrenceType fromValue(String value) => TaskRecurrenceType.values.firstWhere((item) => item.value == value, orElse: () => TaskRecurrenceType.daily);
}

class TaskSeries {
  const TaskSeries({required this.id, required this.userId, required this.title, this.description, this.projectId, this.milestoneId, this.priority = 0, required this.recurrenceType, this.recurrenceInterval = 1, this.timezone = 'UTC', required this.startsAt, this.untilAt, this.occurrenceCount, this.isActive = true, this.createdAt, this.updatedAt});

  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? projectId;
  final String? milestoneId;
  final int priority;
  final TaskRecurrenceType recurrenceType;
  final int recurrenceInterval;
  final String timezone;
  final DateTime startsAt;
  final DateTime? untilAt;
  final int? occurrenceCount;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TaskSeries.fromMap(String id, Map<String, dynamic> map) => TaskSeries(id: id, userId: map['user_id'] as String? ?? map['userId'] as String, title: map['title'] as String, description: map['description'] as String?, projectId: map['project_id'] as String? ?? map['projectId'] as String?, milestoneId: map['milestone_id'] as String? ?? map['milestoneId'] as String?, priority: (map['priority'] as num?)?.toInt() ?? 0, recurrenceType: TaskRecurrenceType.fromValue(map['recurrence_type'] as String? ?? map['recurrenceType'] as String? ?? 'daily'), recurrenceInterval: (map['recurrence_interval'] as num?)?.toInt() ?? 1, timezone: map['timezone']?.toString() ?? 'UTC', startsAt: Task._date(map['starts_at'] ?? map['startsAt'])!, untilAt: Task._date(map['until_at'] ?? map['untilAt']), occurrenceCount: (map['occurrence_count'] as num?)?.toInt(), isActive: map['is_active'] as bool? ?? map['isActive'] as bool? ?? true, createdAt: Task._date(map['created_at'] ?? map['createdAt']), updatedAt: Task._date(map['updated_at'] ?? map['updatedAt']));
}

class TaskReopenResult {
  const TaskReopenResult({required this.reopened, required this.alreadyOpen, this.taskId, this.status, this.firstCompletedAt});
  final bool reopened;
  final bool alreadyOpen;
  final String? taskId;
  final TaskStatus? status;
  final DateTime? firstCompletedAt;

  factory TaskReopenResult.fromMap(Map<String, dynamic> map) => TaskReopenResult(reopened: map['reopened'] as bool? ?? false, alreadyOpen: map['alreadyOpen'] as bool? ?? false, taskId: map['taskId']?.toString(), status: map['status'] == null ? null : TaskStatus.fromValue(map['status'].toString()), firstCompletedAt: Task._date(map['firstCompletedAt']));
}

class TaskCompletionResult {
  const TaskCompletionResult({required this.completed, required this.alreadyCompleted, this.alreadyRewarded = false, this.taskId, this.eventId, this.xpAwarded = 0, this.newXP, this.newLevel, this.newStreak, this.longestStreak, this.totalActivities, this.completedAt, this.firstCompletedAt});
  final bool completed;
  final bool alreadyCompleted;
  final bool alreadyRewarded;
  final String? taskId;
  final String? eventId;
  final int xpAwarded;
  final int? newXP;
  final int? newLevel;
  final int? newStreak;
  final int? longestStreak;
  final int? totalActivities;
  final DateTime? completedAt;
  final DateTime? firstCompletedAt;

  factory TaskCompletionResult.fromMap(Map<String, dynamic> map) => TaskCompletionResult(completed: map['completed'] as bool? ?? false, alreadyCompleted: map['alreadyCompleted'] as bool? ?? false, alreadyRewarded: map['alreadyRewarded'] as bool? ?? false, taskId: map['taskId']?.toString(), eventId: map['eventId']?.toString(), xpAwarded: (map['xpAwarded'] as num?)?.toInt() ?? 0, newXP: (map['newXP'] as num?)?.toInt(), newLevel: (map['newLevel'] as num?)?.toInt(), newStreak: (map['newStreak'] as num?)?.toInt(), longestStreak: (map['longestStreak'] as num?)?.toInt(), totalActivities: (map['totalActivities'] as num?)?.toInt(), completedAt: Task._date(map['completedAt']), firstCompletedAt: Task._date(map['firstCompletedAt']));
}
