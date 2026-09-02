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
}

class DailyChallengeAssignment {
  const DailyChallengeAssignment({required this.challengeId, required this.date, required this.assignedAt, this.completedAt, this.completed = false});
  final String challengeId, date;
  final DateTime assignedAt;
  final DateTime? completedAt;
  final bool completed;
}
