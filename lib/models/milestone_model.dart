class Milestone {
  const Milestone({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.name,
    this.description,
    this.status = MilestoneStatus.active,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String userId;
  final String name;
  final String? description;
  final MilestoneStatus status;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Milestone.fromMap(String id, Map<String, dynamic> map) => Milestone(
        id: id,
        projectId: map['project_id'] as String? ?? map['projectId'] as String,
        userId: map['user_id'] as String? ?? map['userId'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        status: MilestoneStatus.fromValue(map['status'] as String? ?? 'active'),
        dueDate: _date(map['due_date'] ?? map['dueDate']),
        createdAt: _date(map['created_at'] ?? map['createdAt']),
        updatedAt: _date(map['updated_at'] ?? map['updatedAt']),
      );

  static DateTime? _date(Object? value) => value == null
      ? null
      : (value is DateTime ? value : DateTime.tryParse(value.toString()));
}

enum MilestoneStatus {
  active('active'),
  completed('completed'),
  archived('archived');

  const MilestoneStatus(this.value);
  final String value;

  static MilestoneStatus fromValue(String value) => MilestoneStatus.values.firstWhere(
        (item) => item.value == value,
        orElse: () => MilestoneStatus.active,
      );
}

class ProgressStats {
  const ProgressStats({required this.completed, required this.total});
  final int completed;
  final int total;
  double get fraction => total == 0 ? 0 : completed / total;
  int get percent => (fraction * 100).round();
}
