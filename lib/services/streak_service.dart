import '../core/time/calendar_service.dart';

class StreakResult {
  const StreakResult({required this.previous, required this.current, required this.longest, required this.changed});
  final int previous, current, longest;
  final bool changed;
}

class StreakService {
  static StreakResult calculate({required DateTime? lastActivityDate, required int currentStreak, required int longestStreak, required DateTime today}) {
    final day = DateTime(today.year, today.month, today.day);
    if (lastActivityDate == null) return const StreakResult(previous: 0, current: 1, longest: 1, changed: true);
    final last = DateTime(lastActivityDate.year, lastActivityDate.month, lastActivityDate.day);
    final difference = day.difference(last).inDays;
    if (difference == 0) return StreakResult(previous: currentStreak, current: currentStreak, longest: longestStreak, changed: false);
    final next = difference == 1 ? currentStreak + 1 : 1;
    return StreakResult(previous: currentStreak, current: next, longest: next > longestStreak ? next : longestStreak, changed: true);
  }

  static StreakResult calculateForCalendar({required DateTime? lastActivityDate, required int currentStreak, required int longestStreak, required DateTime today, required CalendarService calendar}) {
    if (lastActivityDate == null) return const StreakResult(previous: 0, current: 1, longest: 1, changed: true);
    final difference = calendar.calendarDayDifference(lastActivityDate, today);
    if (difference == 0) return StreakResult(previous: currentStreak, current: currentStreak, longest: longestStreak, changed: false);
    final next = difference == 1 ? currentStreak + 1 : 1;
    return StreakResult(previous: currentStreak, current: next, longest: next > longestStreak ? next : longestStreak, changed: true);
  }
}
