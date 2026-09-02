import '../models/achievement_model.dart';

const achievementDefinitions = <AchievementDefinition>[
  AchievementDefinition(id: 'FIRST_STEP', name: 'First Step', description: 'Complete your first challenge', type: AchievementType.activityCount, threshold: 1, xpReward: 25, iconAsset: 'first_step'),
  AchievementDefinition(id: 'GETTING_STARTED', name: 'Getting Started', description: 'Reach a 3-day streak', type: AchievementType.streak, threshold: 3, xpReward: 50, iconAsset: 'getting_started'),
  AchievementDefinition(id: 'WEEK_WARRIOR', name: 'Week Warrior', description: 'Reach a 7-day streak', type: AchievementType.streak, threshold: 7, xpReward: 100, iconAsset: 'week_warrior'),
  AchievementDefinition(id: 'TWO_WEEKS', name: 'Two Weeks', description: 'Reach a 14-day streak', type: AchievementType.streak, threshold: 14, xpReward: 150, iconAsset: 'two_weeks'),
  AchievementDefinition(id: 'UNSTOPPABLE', name: 'Unstoppable', description: 'Reach a 30-day streak', type: AchievementType.streak, threshold: 30, xpReward: 300, iconAsset: 'unstoppable'),
  AchievementDefinition(id: 'CENTURY', name: 'Century', description: 'Complete 100 challenges', type: AchievementType.activityCount, threshold: 100, xpReward: 500, iconAsset: 'century'),
  AchievementDefinition(id: 'EXPLORER', name: 'Explorer', description: 'Complete challenges from 5 categories', type: AchievementType.categoryCount, threshold: 5, xpReward: 150, iconAsset: 'explorer'),
  AchievementDefinition(id: 'MASTER_EXPLORER', name: 'Master Explorer', description: 'Complete every challenge category', type: AchievementType.categoryCount, threshold: 8, xpReward: 300, iconAsset: 'master_explorer'),
];
