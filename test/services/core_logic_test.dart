import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/services/streak_service.dart';
import 'package:pulse/services/xp_service.dart';

void main() {
  group('StreakService', () {
    final day1 = DateTime(2026, 1, 1);
    test('first activity starts at one', () => expect(StreakService.calculate(lastActivityDate: null, currentStreak: 0, longestStreak: 0, today: day1).current, 1));
    test('same day does not increase', () => expect(StreakService.calculate(lastActivityDate: day1, currentStreak: 3, longestStreak: 3, today: day1).current, 3));
    test('consecutive day increases', () => expect(StreakService.calculate(lastActivityDate: day1, currentStreak: 3, longestStreak: 3, today: day1.add(const Duration(days: 1))).current, 4));
    test('missed day resets', () => expect(StreakService.calculate(lastActivityDate: day1, currentStreak: 3, longestStreak: 3, today: day1.add(const Duration(days: 2))).current, 1));
    test('longest streak updates', () => expect(StreakService.calculate(lastActivityDate: day1, currentStreak: 3, longestStreak: 3, today: day1.add(const Duration(days: 1))).longest, 4));
  });

  group('XPService', () {
    test('levels follow configured thresholds', () => expect(XPService.levelForXP(250), 3));
    test('award reports level up', () => expect(XPService.award(currentXP: 90, amount: 25).leveledUp, true));
  });
}
