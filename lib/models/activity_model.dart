class ActivityModel {
  const ActivityModel({required this.id, required this.userId, required this.challengeId, required this.date, required this.xpAwarded, required this.completedAt});
  final String id, userId, challengeId, date;
  final int xpAwarded;
  final DateTime completedAt;
}

class ShareCardData {
  const ShareCardData({this.username, this.avatarUrl, required this.statLabel, required this.statValue, this.achievementName, this.achievementDescription, required this.currentStreak, required this.longestStreak, required this.level, required this.xp});
  final String? username, avatarUrl;
  final String statLabel, statValue;
  final String? achievementName, achievementDescription;
  final int currentStreak, longestStreak, level, xp;
}
