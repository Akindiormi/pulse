import 'package:pulse/models/calendar_event_model.dart';

/// Expands the supported RRULE-style recurrence subset for the visible range.
/// Generated occurrences remain in memory; no occurrence rows are persisted.
class CalendarRecurrence {
  const CalendarRecurrence._();

  static List<CalendarEvent> expand(CalendarEvent event, {required DateTime rangeStart, required DateTime rangeEnd}) {
    if (!event.isRecurring) {
      return event.startsAt.isBefore(rangeEnd) && event.endsAt.isAfter(rangeStart) ? [event] : const [];
    }
    final values = _parse(event.recurrenceRule!);
    final freq = values['FREQ'];
    if (freq == null) return const [];
    final interval = int.tryParse(values['INTERVAL'] ?? '1') ?? 1;
    if (interval < 1) return const [];
    final count = int.tryParse(values['COUNT'] ?? '');
    final until = _parseUntil(values['UNTIL']);
    final duration = event.endsAt.difference(event.startsAt);
    final weekdays = _parseByDay(values['BYDAY']);
    final results = <CalendarEvent>[];
    var occurrence = event.startsAt;
    var generated = 0;

    for (var i = 0; i < 5000; i++) {
      if (count != null && generated >= count) break;
      if (until != null && occurrence.isAfter(until)) break;
      if (occurrence.isAfter(rangeEnd)) break;
      final candidates = freq == 'WEEKLY' && weekdays.isNotEmpty
          ? _weeklyCandidates(occurrence, interval, weekdays, event.startsAt)
          : [occurrence];
      for (final start in candidates) {
        if (count != null && generated >= count) break;
        if (start.isBefore(event.startsAt)) continue;
        if (until != null && start.isAfter(until)) continue;
        generated++;
        final end = start.add(duration);
        if (start.isBefore(rangeEnd) && end.isAfter(rangeStart)) {
          results.add(event.copyWith(startsAt: start, endsAt: end));
        }
      }
      occurrence = _advance(occurrence, freq, interval);
    }
    return results;
  }

  static Map<String, String> _parse(String rule) {
    final map = <String, String>{};
    for (final part in rule.split(';')) {
      final pieces = part.split('=');
      if (pieces.length >= 2) map[pieces.first.trim().toUpperCase()] = pieces.sublist(1).join('=').trim();
    }
    return map;
  }

  static DateTime? _parseUntil(String? value) {
    if (value == null || value.isEmpty) return null;
    final raw = value.endsWith('Z') ? value.substring(0, value.length - 1) : value;
    if (RegExp(r'^\d{8}T\d{6}$').hasMatch(raw)) {
      final parsed = DateTime.tryParse('${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}T${raw.substring(9, 11)}:${raw.substring(11, 13)}:${raw.substring(13, 15)}Z');
      return parsed?.toUtc();
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  static Set<int> _parseByDay(String? value) {
    const days = {'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6, 'SU': 7};
    if (value == null) return const {};
    return value.split(',').map((day) => days[day.trim().toUpperCase().replaceAll(RegExp(r'[-+]?\d+'), '')]).whereType<int>().toSet();
  }

  static List<DateTime> _weeklyCandidates(DateTime anchor, int interval, Set<int> weekdays, DateTime seriesStart) {
    final weekStart = anchor.subtract(Duration(days: anchor.weekday - 1));
    final seriesWeekStart = seriesStart.subtract(Duration(days: seriesStart.weekday - 1));
    return weekdays.map((weekday) {
      final day = weekStart.add(Duration(days: weekday - 1));
      return DateTime(day.year, day.month, day.day, seriesStart.hour, seriesStart.minute, seriesStart.second, seriesStart.millisecond, seriesStart.microsecond);
    }).where((candidate) {
      final weeks = candidate.difference(seriesWeekStart).inDays ~/ 7;
      return weeks >= 0 && weeks % interval == 0;
    }).toList()..sort();
  }

  static DateTime _advance(DateTime date, String freq, int interval) {
    switch (freq) {
      case 'DAILY': return date.add(Duration(days: interval));
      case 'WEEKLY': return date.add(Duration(days: 7 * interval));
      case 'MONTHLY': return _addMonths(date, interval);
      case 'YEARLY': return date.copyWith(year: date.year + interval);
      default: return date.add(Duration(days: interval));
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
