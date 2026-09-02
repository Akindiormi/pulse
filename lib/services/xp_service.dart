class XPResult {
  const XPResult({required this.previousXP, required this.newXP, required this.previousLevel, required this.newLevel, required this.leveledUp});
  final int previousXP, newXP, previousLevel, newLevel;
  final bool leveledUp;
}

class XPService {
  static const rewards = <String, int>{'easy': 10, 'medium': 25, 'hard': 50, 'wild': 75};
  static const thresholds = <int>[0, 100, 250, 450, 700, 1000, 1400, 1850, 2350, 2900];

  static int levelForXP(int xp) {
    var level = 1;
    for (var i = 0; i < thresholds.length; i++) {
      if (xp >= thresholds[i]) level = i + 1;
    }
    if (xp >= thresholds.last) {
      level = thresholds.length + ((xp - thresholds.last) ~/ 650);
    }
    return level;
  }

  static XPResult award({required int currentXP, required int amount}) {
    final next = currentXP + amount;
    final previousLevel = levelForXP(currentXP);
    final newLevel = levelForXP(next);
    return XPResult(previousXP: currentXP, newXP: next, previousLevel: previousLevel, newLevel: newLevel, leveledUp: newLevel > previousLevel);
  }

  static int nextLevelXP(int xp) {
    final level = levelForXP(xp);
    if (level < thresholds.length) return thresholds[level];
    return thresholds.last + ((level - thresholds.length + 1) * 650);
  }

  static double progress(int xp) {
    final level = levelForXP(xp);
    final current = level <= thresholds.length ? thresholds[level - 1] : thresholds.last + ((level - thresholds.length) * 650);
    final next = nextLevelXP(xp);
    return ((xp - current) / (next - current)).clamp(0, 1).toDouble();
  }
}
