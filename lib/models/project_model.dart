class Project {
  const Project({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.status = ProjectStatus.active,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String? description;
  final ProjectStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Project.fromMap(String id, Map<String, dynamic> map) => Project(
        id: id,
        userId: map['user_id'] as String? ?? map['userId'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        status: ProjectStatus.fromValue(map['status'] as String? ?? 'active'),
        createdAt: _date(map['created_at'] ?? map['createdAt']),
        updatedAt: _date(map['updated_at'] ?? map['updatedAt']),
      );

  static DateTime? _date(Object? value) => value == null
      ? null
      : (value is DateTime ? value : DateTime.tryParse(value.toString()));
}

enum ProjectStatus {
  active('active'),
  completed('completed'),
  archived('archived');

  const ProjectStatus(this.value);
  final String value;

  static ProjectStatus fromValue(String value) => ProjectStatus.values.firstWhere(
        (item) => item.value == value,
        orElse: () => ProjectStatus.active,
      );
}
