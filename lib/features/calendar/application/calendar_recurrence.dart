import 'package:pulse/models/calendar_event_model.dart';

/// Expands the supported RRULE-style recurrence subset for the visible range.
/// Generated occurrences remain in memory; no occurrence rows are persisted.
///
/// Supported v1 rules: DAILY, WEEKLY, MONTHLY and YEARLY, plus INTERVAL,
/// COUNT, UNTIL and WEEKLY BYDAY. Per-occurrence exceptions are intentionally
/// not supported.
class CalendarRecurrence {
  const CalendarRecurrence._();

  static List<CalendarEvent> expand(
    CalendarEvent event, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    if (!rangeEnd.isAfter(rangeStart)) return const [];

    if (!event.isRecurring) {
      return _overlaps(event.startsAt, event.endsAt, rangeStart, rangeEnd)
          ? [event]
          : const [];
    }

    final values = _parse(event.recurrenceRule!);
    final freq = values['FREQ'];
    if (freq == null || !{'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'}.contains(freq)) {
      return const [];
    }

    final interval = int.tryParse(values['INTERVAL'] ?? '1') ?? 1;
    if (interval < 1) return const [];

    final count = int.tryParse(values['COUNT'] ?? '');
    if (count != null && count < 1) return const [];

    final until = _parseUntil(values['UNTIL']);
    final duration = event.endsAt.difference(event.startsAt);
    final weekdays = freq == 'WEEKLY' ? _parseByDay(values['BYDAY']) : const <int>{};
    final results = <CalendarEvent>[];

    var anchor = event.startsAt;
    var occurrenceCount = 0;

    // The requested range is the hard read boundary. The finite safety cap
    // protects the client from malformed rules without materializing future rows.
    for (var i = 0; i < 5000; i++) {
      if (count != null && occurrenceCount >= count) break;
      if (until != null && anchor.isAfter(until)) break;
      if (anchor.isAfter(rangeEnd)) break;

      final candidates = freq == 'WEEKLY' && weekdays.isNotEmpty
          ? _weeklyCandidates(anchor, interval, weekdays, event.startsAt)
          : [anchor];

      for (final start in candidates) {
        if (count != null && occurrenceCount >= count) break;
        if (start.isBefore(event.startsAt)) continue;
        if (until != null && start.isAfter(until)) continue;

        occurrenceCount++;
        final end = start.add(duration);
        if (_overlaps(start, end, rangeStart, rangeEnd)) {
          results.add(event.copyWith(startsAt: start, endsAt: end));
        }
      }

      anchor = _advance(anchor, freq, interval);
    }

    return results;
  }

  static bool _overlaps(
    DateTime eventStart,
    DateTime eventEnd,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => eventStart.isBefore(rangeEnd) && eventEnd.isAfter(rangeStart);

  static Map<String, String> _parse(String rule) {
    final map = <String, String>{};
    for (final part in rule.split(';')) {
      final pieces = part.split('=');
      if (pieces.length >= 2) {
        map[pieces.first.trim().toUpperCase()] =
            pieces.sublist(1).join('=').trim().toUpperCase();
      }
    }
    return map;
  }

  static DateTime? _parseUntil(String? value) {
    if (value == null || value.isEmpty) return null;
    final trimmed = value.trim();
    final raw = trimmed.endsWith('Z')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;

    if (RegExp(r'^\d{8}T\d{6}$').hasMatch(raw)) {
      final normalized =
          '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}'
          'T${raw.substring(9, 11)}:${raw.substring(11, 13)}:${raw.substring(13, 15)}Z';
      return DateTime.tryParse(normalized)?.toUtc();
    }

    return DateTime.tryParse(trimmed)?.toUtc();
  }

  static Set<int> _parseByDay(String? value) {
    const days = <String, int>{
      'MO': DateTime.monday,
      'TU': DateTime.tuesday,
      'WE': DateTime.wednesday,
      'TH': DateTime.thursday,
      'FR': DateTime.friday,
      'SA': DateTime.saturday,
      'SU': DateTime.sunday,
    };
    if (value == null || value.trim().isEmpty) return const <int>{};

    return value
        .split(',')
        .map((day) => day.trim().toUpperCase().replaceAll(RegExp(r'[-+]?\d+'), ''))
        .map((day) => days[day])
        .whereType<int>()
        .toSet();
  }

  static List<DateTime> _weeklyCandidates(
    DateTime anchor,
    int interval,
    Set<int> weekdays,
    DateTime seriesStart,
  ) {
    final weekStart = _startOfWeek(anchor);
    final seriesWeekStart = _startOfWeek(seriesStart);

    return weekdays
        .map((weekday) => _sameClock(
              weekStart.add(Duration(days: weekday - 1)),
              seriesStart,
            ))
        .where((candidate) {
          final days = candidate.difference(seriesWeekStart).inDays;
          final weeks = days ~/ 7;
          return days >= 0 && weeks % interval == 0;
        })
        .toList()
      ..sort();
  }

  static DateTime _startOfWeek(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    return _sameClock(start, DateTime(start.year, start.month, start.day));
  }

  static DateTime _sameClock(DateTime date, DateTime clock) {
    if (date.isUtc || clock.isUtc) {
      return DateTime.utc(
        date.year,
        date.month,
        date.day,
        clock.hour,
        clock.minute,
        clock.second,
        clock.millisecond,
        clock.microsecond,
      );
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      clock.hour,
      clock.minute,
      clock.second,
      clock.millisecond,
      clock.microsecond,
    );
  }

  static DateTime _advance(DateTime date, String freq, int interval) {
    switch (freq) {
      case 'DAILY':
        return date.add(Duration(days: interval));
      case 'WEEKLY':
        return date.add(Duration(days: 7 * interval));
      case 'MONTHLY':
        return _addMonths(date, interval);
      case 'YEARLY':
        return date.copyWith(year: date.year + interval);
      default:
        return date;
    }
  }

  static DateTime _addMonths(DateTime date, int months) {
    final targetMonth = date.month - 1 + months;
    final year = date.year + targetMonth ~/ 12;
    final month = targetMonth % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return date.copyWith(
      year: year,
      month: month,
      day: date.day.clamp(1, lastDay),
    );
  }
}
