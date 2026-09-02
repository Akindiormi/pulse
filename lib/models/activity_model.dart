class ActivityModel {
  const ActivityModel({required this.id, required this.userId, required this.challengeId, required this.date, required this.xpAwarded, required this.completedAt});
  final String id, userId, challengeId, date;
  final int xpAwarded;
  final DateTime completedAt;

  Map<String, dynamic> toMap() => {'userId': userId, 'challengeId': challengeId, 'date': date, 'xpAwarded': xpAwarded, 'completedAt': completedAt};

  factory ActivityModel.fromMap(String id, Map<String, dynamic> map) => ActivityModel(
        id: id,
        userId: map['userId'] as String? ?? '',
        challengeId: map['challengeId'] as String? ?? '',
        date: map['date'] as String? ?? '',
        xpAwarded: (map['xpAwarded'] as num?)?.toInt() ?? 0,
        completedAt: _date(map['completedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
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

class ShareCardData {
  const ShareCardData({this.username, this.avatarUrl, required this.statLabel, required this.statValue, this.achievementName, this.achievementDescription, required this.currentStreak, required this.longestStreak, required this.level, required this.xp});
  final String? username, avatarUrl;
  final String statLabel, statValue;
  final String? achievementName, achievementDescription;
  final int currentStreak, longestStreak, level, xp;
}
