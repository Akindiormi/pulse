enum FocusSessionStatus {
  running('running'),
  paused('paused'),
  completed('completed'),
  cancelled('cancelled');

  const FocusSessionStatus(this.value);
  final String value;

  static FocusSessionStatus fromValue(String value) => FocusSessionStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => throw ArgumentError('Unknown Focus session status: $value'),
      );

  bool get isActive => this == running || this == paused;
  bool get isTerminal => this == completed || this == cancelled;
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.userId,
    required this.status,
    required this.plannedDurationSeconds,
    required this.startedAt,
    required this.activeDurationSeconds,
    this.taskId,
    this.endedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String? taskId;
  final FocusSessionStatus status;
  final int plannedDurationSeconds;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int activeDurationSeconds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isRunning => status == FocusSessionStatus.running;
  bool get isPaused => status == FocusSessionStatus.paused;
  bool get isTerminal => status.isTerminal;

  FocusSession copyWith({
    String? taskId,
    FocusSessionStatus? status,
    int? activeDurationSeconds,
    DateTime? endedAt,
    DateTime? updatedAt,
  }) => FocusSession(
        id: id,
        userId: userId,
        taskId: taskId ?? this.taskId,
        status: status ?? this.status,
        plannedDurationSeconds: plannedDurationSeconds,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        activeDurationSeconds: activeDurationSeconds ?? this.activeDurationSeconds,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory FocusSession.fromMap(String id, Map<String, dynamic> map) => FocusSession(
        id: id,
        userId: map['user_id'] as String? ?? map['userId'] as String,
        taskId: map['task_id'] as String? ?? map['taskId'] as String?,
        status: FocusSessionStatus.fromValue(map['status'] as String),
        plannedDurationSeconds: (map['planned_duration_seconds'] as num?)?.toInt() ??
            (map['plannedDurationSeconds'] as num).toInt(),
        startedAt: _date(map['started_at'] ?? map['startedAt'])!,
        endedAt: _date(map['ended_at'] ?? map['endedAt']),
        activeDurationSeconds: (map['active_duration_seconds'] as num?)?.toInt() ??
            (map['activeDurationSeconds'] as num?)?.toInt() ??
            0,
        createdAt: _date(map['created_at'] ?? map['createdAt']),
        updatedAt: _date(map['updated_at'] ?? map['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        if (taskId != null) 'task_id': taskId,
        'status': status.value,
        'planned_duration_seconds': plannedDurationSeconds,
        'started_at': startedAt.toUtc().toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt!.toUtc().toIso8601String(),
        'active_duration_seconds': activeDurationSeconds,
      };

  static DateTime? _date(Object? value) =>
      value == null ? null : (value is DateTime ? value : DateTime.tryParse(value.toString()));
}

class FocusIntent {
  const FocusIntent({
    required this.plannedDurationSeconds,
    this.taskId,
    this.calendarEventId,
  }) : assert(plannedDurationSeconds > 0);

  final int plannedDurationSeconds;
  final String? taskId;
  final String? calendarEventId;

  bool get isTaskBound => taskId != null;
  bool get isCalendarBound => calendarEventId != null;

  FocusIntent copyWith({
    int? plannedDurationSeconds,
    String? taskId,
    String? calendarEventId,
  }) => FocusIntent(
        plannedDurationSeconds: plannedDurationSeconds ?? this.plannedDurationSeconds,
        taskId: taskId ?? this.taskId,
        calendarEventId: calendarEventId ?? this.calendarEventId,
      );
}
