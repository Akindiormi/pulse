class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.userId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.description,
    this.allDay = false,
    this.timezone = 'UTC',
    this.recurrenceRule,
    this.createdAt,
    this.updatedAt,
    this.taskIds = const <String>[],
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String timezone;
  final String? recurrenceRule;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> taskIds;

  bool get isRecurring => recurrenceRule != null && recurrenceRule!.trim().isNotEmpty;

  CalendarEvent copyWith({
    String? title,
    String? description,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? allDay,
    String? timezone,
    String? recurrenceRule,
    DateTime? updatedAt,
    List<String>? taskIds,
  }) => CalendarEvent(
    id: id,
    userId: userId,
    title: title ?? this.title,
    description: description ?? this.description,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    allDay: allDay ?? this.allDay,
    timezone: timezone ?? this.timezone,
    recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    taskIds: taskIds ?? this.taskIds,
  );

  factory CalendarEvent.fromMap(String id, Map<String, dynamic> map) => CalendarEvent(
    id: id,
    userId: map['user_id'] as String? ?? map['userId'] as String,
    title: map['title'] as String,
    description: map['description'] as String?,
    startsAt: _date(map['starts_at'] ?? map['startsAt'])!,
    endsAt: _date(map['ends_at'] ?? map['endsAt'])!,
    allDay: map['all_day'] as bool? ?? map['allDay'] as bool? ?? false,
    timezone: map['timezone'] as String? ?? 'UTC',
    recurrenceRule: map['recurrence_rule'] as String? ?? map['recurrenceRule'] as String?,
    createdAt: _date(map['created_at'] ?? map['createdAt']),
    updatedAt: _date(map['updated_at'] ?? map['updatedAt']),
    taskIds: ((map['task_ids'] ?? map['taskIds']) as List<dynamic>?)?.whereType<String>().toList(growable: false) ?? const <String>[],
  );

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'title': title,
    if (description != null) 'description': description,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'all_day': allDay,
    'timezone': timezone,
    if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
  };

  static DateTime? _date(Object? value) => value == null ? null : (value is DateTime ? value : DateTime.tryParse(value.toString()));
}
