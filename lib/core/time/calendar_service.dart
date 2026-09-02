class CalendarService {
  const CalendarService({this.now = _systemNow, this.timeZoneOffset});

  final DateTime Function() now;
  final Duration? timeZoneOffset;

  static DateTime _systemNow() => DateTime.now();

  DateTime current() {
    final value = now();
    return timeZoneOffset == null ? value : value.toUtc().add(timeZoneOffset!);
  }

  String todayKey() => keyFor(current());

  String keyFor(DateTime value) {
    final local = timeZoneOffset == null ? value : value.toUtc().add(timeZoneOffset!);
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  int calendarDayDifference(DateTime? previous, DateTime current) {
    if (previous == null) return 0;
    final a = DateTime.parse(keyFor(previous));
    final b = DateTime.parse(keyFor(current));
    return b.difference(a).inDays;
  }
}
