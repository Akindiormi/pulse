class UserModel {
  const UserModel({
    required this.uid,
    this.username,
    this.displayName,
    this.photoUrl,
    this.createdAt,
    this.totalActivities = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.xp = 0,
    this.level = 1,
    this.lastActivityDate,
    this.completedCategories = const <String>{},
    this.unlockedAchievements = const <String>{},
  });

  final String uid;
  final String? username, displayName, photoUrl;
  final DateTime? createdAt, lastActivityDate;
  final int totalActivities, currentStreak, longestStreak, xp, level;
  final Set<String> completedCategories, unlockedAchievements;

  UserModel copyWith({
    String? username,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    int? totalActivities,
    int? currentStreak,
    int? longestStreak,
    int? xp,
    int? level,
    DateTime? lastActivityDate,
    Set<String>? completedCategories,
    Set<String>? unlockedAchievements,
  }) => UserModel(
        uid: uid,
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        createdAt: createdAt ?? this.createdAt,
        totalActivities: totalActivities ?? this.totalActivities,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        xp: xp ?? this.xp,
        level: level ?? this.level,
        lastActivityDate: lastActivityDate ?? this.lastActivityDate,
        completedCategories: completedCategories ?? this.completedCategories,
        unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      );

  Map<String, dynamic> toMap() => {
        'username': username,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'createdAt': createdAt,
        'totalActivities': totalActivities,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'xp': xp,
        'level': level,
        'lastActivityDate': lastActivityDate,
        'completedCategories': completedCategories.toList()..sort(),
        'unlockedAchievements': unlockedAchievements.toList()..sort(),
      };

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) => UserModel(
        uid: uid,
        username: map['username'] as String?,
        displayName: map['displayName'] as String?,
        photoUrl: map['photoUrl'] as String?,
        createdAt: _date(map['createdAt']),
        totalActivities: (map['totalActivities'] as num?)?.toInt() ?? 0,
        currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
        xp: (map['xp'] as num?)?.toInt() ?? 0,
        level: (map['level'] as num?)?.toInt() ?? 1,
        lastActivityDate: _date(map['lastActivityDate']),
        completedCategories: Set<String>.from((map['completedCategories'] as List?)?.whereType<String>() ?? const <String>[]),
        unlockedAchievements: Set<String>.from((map['unlockedAchievements'] as List?)?.whereType<String>() ?? const <String>[]),
      );

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
