enum ChallengeCategory { random, social, health, money, learning, confidence, creativity, mindfulness }
enum Difficulty { easy, medium, hard, wild }

class Challenge {
  const Challenge({required this.id, required this.title, required this.description, required this.category, required this.difficulty, required this.xpReward, required this.estimatedMinutes, this.estimatedCost, required this.active, this.createdAt});
  final String id, title, description;
  final ChallengeCategory category;
  final Difficulty difficulty;
  final int xpReward, estimatedMinutes;
  final double? estimatedCost;
  final bool active;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'category': category.name,
        'difficulty': difficulty.name,
        'xpReward': xpReward,
        'estimatedMinutes': estimatedMinutes,
        'estimatedCost': estimatedCost,
        'active': active,
        'createdAt': createdAt,
      };

  factory Challenge.fromMap(String id, Map<String, dynamic> map) => Challenge(
        id: id,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        category: _category(map['category']),
        difficulty: _difficulty(map['difficulty']),
        xpReward: (map['xpReward'] as num?)?.toInt() ?? 0,
        estimatedMinutes: (map['estimatedMinutes'] as num?)?.toInt() ?? 0,
        estimatedCost: (map['estimatedCost'] as num?)?.toDouble(),
        active: map['active'] as bool? ?? false,
        createdAt: _date(map['createdAt']),
      );

  static ChallengeCategory _category(Object? value) => ChallengeCategory.values.firstWhere((e) => e.name == value, orElse: () => ChallengeCategory.random);
  static Difficulty _difficulty(Object? value) => Difficulty.values.firstWhere((e) => e.name == value, orElse: () => Difficulty.easy);
  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.tryParse(value.toString());
    }
  }
}

class DailyChallengeAssignment {
  const DailyChallengeAssignment({required this.challengeId, required this.date, required this.assignedAt, this.completedAt, this.completed = false});
  final String challengeId, date;
  final DateTime assignedAt;
  final DateTime? completedAt;
  final bool completed;

  Map<String, dynamic> toMap() => {'challengeId': challengeId, 'date': date, 'assignedAt': assignedAt, 'completedAt': completedAt, 'completed': completed};

  factory DailyChallengeAssignment.fromMap(Map<String, dynamic> map, {String? date}) => DailyChallengeAssignment(
        challengeId: map['challengeId'] as String? ?? '',
        date: map['date'] as String? ?? date ?? '',
        assignedAt: Challenge._date(map['assignedAt']) ?? DateTime.now(),
        completedAt: Challenge._date(map['completedAt']),
        completed: map['completed'] as bool? ?? false,
      );
}
