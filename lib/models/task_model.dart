class Task {
  const Task({required this.id, required this.userId, required this.title, this.description, this.status = TaskStatus.todo, this.dueDate, this.dueTime, this.projectId, this.milestoneId, this.priority = 0, this.completedAt, this.createdAt, this.updatedAt});

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
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCompleted => status == TaskStatus.completed;
  bool get isOpen => status == TaskStatus.todo || status == TaskStatus.inProgress;

  factory Task.fromMap(String id, Map<String, dynamic> map) => Task(
        id: id,
        userId: map['user_id'] as String? ?? map['userId'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        status: TaskStatus.fromValue(map['status'] as String? ?? 'todo'),
        dueDate: _date(map['due_date'] ?? map['dueDate']),
        dueTime: map['due_time']?.toString() ?? map['dueTime']?.toString(),
        projectId: map['project_id'] as String? ?? map['projectId'] as String?,
        milestoneId: map['milestone_id'] as String? ?? map['milestoneId'] as String?,
        priority: (map['priority'] as num?)?.toInt() ?? 0,
        completedAt: _date(map['completed_at'] ?? map['completedAt']),
        createdAt: _date(map['created_at'] ?? map['createdAt']),
        updatedAt: _date(map['updated_at'] ?? map['updatedAt']),
      );

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

class TaskCompletionResult {
  const TaskCompletionResult({required this.completed, required this.alreadyCompleted, this.taskId, this.eventId, this.xpAwarded = 0, this.newXP, this.newLevel, this.newStreak, this.longestStreak, this.totalActivities, this.completedAt});

  final bool completed;
  final bool alreadyCompleted;
  final String? taskId;
  final String? eventId;
  final int xpAwarded;
  final int? newXP;
  final int? newLevel;
  final int? newStreak;
  final int? longestStreak;
  final int? totalActivities;
  final DateTime? completedAt;

  factory TaskCompletionResult.fromMap(Map<String, dynamic> map) => TaskCompletionResult(
        completed: map['completed'] as bool? ?? false,
        alreadyCompleted: map['alreadyCompleted'] as bool? ?? false,
        taskId: map['taskId']?.toString(),
        eventId: map['eventId']?.toString(),
        xpAwarded: (map['xpAwarded'] as num?)?.toInt() ?? 0,
        newXP: (map['newXP'] as num?)?.toInt(),
        newLevel: (map['newLevel'] as num?)?.toInt(),
        newStreak: (map['newStreak'] as num?)?.toInt(),
        longestStreak: (map['longestStreak'] as num?)?.toInt(),
        totalActivities: (map['totalActivities'] as num?)?.toInt(),
        completedAt: Task._date(map['completedAt']),
      );
}
