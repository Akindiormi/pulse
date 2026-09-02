class UserModel {
  const UserModel({required this.uid, this.username, this.displayName, this.photoUrl, this.createdAt, this.totalActivities = 0, this.currentStreak = 0, this.longestStreak = 0, this.xp = 0, this.level = 1, this.lastActivityDate});
  final String uid;
  final String? username, displayName, photoUrl;
  final DateTime? createdAt, lastActivityDate;
  final int totalActivities, currentStreak, longestStreak, xp, level;
}
