import 'package:pulse/models/calendar_event_model.dart';

/// Expands the supported RRULE-style recurrence subset for the visible range.
///
/// Slice 3 intentionally keeps recurrence series-level only: generated
/// occurrences are ephemeral and are never written back to Supabase.
class CalendarRecurrence {
  const CalendarRecurrence._();

  static List<CalendarEvent> expand(
    CalendarEvent event, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final rule = event.recurrenceRule;
    if (rule == null || rule.trim().isEmpty) {
      return _overlaps(event, rangeStart, rangeEnd) ? [event] : const [];
    }

    final values = _parse(rule);
    final freq = values['FREQ'];
    if (freq == null) return const [];

    final interval = int.tryParse(values['INTERVAL'] ?? '1') ?? 1;
    if (interval < 1) return const [];

    final count = int.tryParse(values['COUNT'] ?? '');
    final until = _parseUntil(values['UNTIL']);
    final duration = event.endsAt.difference(event.startsAt);
    final results = <CalendarEvent>[];

    // v1 supports DAILY, WEEKLY, MONTHLY and YEARLY series. BYDAY is
    // supported for WEEKLY using ISO weekday numbers (MO=1 ... SU=7).
    final weekdays = _parseByDay(values['BYDAY']);
    var occurrence = event.startsAt;
    var generated = 0;

    // Bound iteration by the visible range plus one event duration. This
    // guarantees an open-ended recurrence is never expanded indefinitely.
    final safetyLimit = 5000;
    for (var i = 0; i < safetyLimit; i++) {
      if (count != null && generated >= count) break;
      if (until != null && occurrence.isAfter(until)) break;
      if (occurrence.isAfter(rangeEnd)) break;

      final candidates = freq == 'WEEKLY' && weekdays.isNotEmpty
          ? _weeklyCandidates(occurrence, interval, weekdays, event.startsAt)
          : [occurrence];

      for (final start in candidates) {
        if (count != null && generated >= count) break;
        if (until != null && start.isAfter(until)) continue;
        if (start.isBefore(event.startsAt)) continue;
        if (_overlapsWindow(start, start.add(duration), rangeStart, rangeEnd)) {
          results.add(event.copyWith(
            startsAt: start,
            endsAt: start.add(duration),
            // Generated occurrences are not separate persisted events.
            occurrenceStart: start,
          ));
        }
        generated++;
      }

      occurrence = _advance(occurrence, freq, interval);
    }

    return results;
  }

  static bool _overlaps(CalendarEvent event, DateTime start, DateTime end) =>
      event.startsAt.isBefore(end) && event.endsAt.isAfter(start);

  static bool _overlapsWindow(
    DateTime eventStart,
    DateTime eventEnd,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) =>
      eventStart.isBefore(rangeEnd) && eventEnd.isAfter(rangeStart);

  static Map<String, String> _parse(String rule) {
    final map = <String, String>{};
    for (final part in rule.split(';')) {
      final pieces = part.split('=');
      if (pieces.length >= 2) {
        map[pieces.first.trim().toUpperCase()] = pieces.sublist(1).join('=').trim();
      }
    }
    return map;
  }

  static DateTime? _parseUntil(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.endsWith('Z') ? value : '${value}Z';
    return DateTime.tryParse(normalized)?.toUtc();
  }

  static Set<int> _parseByDay(String? value) {
    const days = {'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6, 'SU': 7};
    if (value == null) return const {};
    return value.split(',').map((day) {
      final key = day.trim().toUpperCase().replaceAll(RegExp(r'[-+]?\d+'), '');
      return days[key];
    }).whereType<int>().toSet();
  }

  static List<DateTime> _weeklyCandidates(
    DateTime anchor,
    int interval,
    Set<int> weekdays,
    DateTime seriesStart,
  ) {
    final weekStart = anchor.subtract(Duration(days: anchor.weekday - 1));
    return weekdays.map((weekday) {
      final candidate = weekStart.add(Duration(days: weekday - 1)).copyWith(
        hour: seriesStart.hour,
        minute: seriesStart.minute,
        second: seriesStart.second,
        millisecond: seriesStart.millisecond,
        microsecond: seriesStart.microsecond,
      );
      return candidate;
    }).where((candidate) {
      final weeks = candidate.difference(
        seriesStart.subtract(Duration(days: seriesStart.weekday - 1)),
      ).inDays ~/ 7;
      return weeks >= 0 && weeks % interval == 0;
    }).toList()..sort();
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
        return date.add(Duration(days: interval));
    }
  }

  static DateTime _addMonths(DateTime date, int months) {
    final targetMonth = date.month - 1 + months;
    final year = date.year + targetMonth ~/ 12;
    final month = targetMonth % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return date.copyWith(year: year, month: month, day: date.day.clamp(1, lastDay));
  }
}
