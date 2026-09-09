import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/calendar/application/calendar_recurrence.dart';
import 'package:pulse/models/calendar_event_model.dart';

CalendarEvent event({String? rule}) => CalendarEvent(
      id: 'event-1',
      userId: 'user-1',
      title: 'Study',
      startsAt: DateTime.utc(2026, 9, 1, 8),
      endsAt: DateTime.utc(2026, 9, 1, 9),
      allDay: false,
      timezone: 'Africa/Lagos',
      recurrenceRule: rule,
    );

void main() {
  test('daily recurrence expands only inside the visible range', () {
    final result = CalendarRecurrence.expand(
      event(rule: 'FREQ=DAILY;INTERVAL=1'),
      rangeStart: DateTime.utc(2026, 9, 3),
      rangeEnd: DateTime.utc(2026, 9, 6),
    );

    expect(result.map((e) => e.startsAt), [
      DateTime.utc(2026, 9, 3, 8),
      DateTime.utc(2026, 9, 4, 8),
      DateTime.utc(2026, 9, 5, 8),
    ]);
  });

  test('count and until stop expansion', () {
    final counted = CalendarRecurrence.expand(
      event(rule: 'FREQ=DAILY;COUNT=2'),
      rangeStart: DateTime.utc(2026, 9, 1),
      rangeEnd: DateTime.utc(2026, 9, 10),
    );
    expect(counted, hasLength(2));

    final until = CalendarRecurrence.expand(
      event(rule: 'FREQ=DAILY;UNTIL=20260903T080000Z'),
      rangeStart: DateTime.utc(2026, 9, 1),
      rangeEnd: DateTime.utc(2026, 9, 10),
    );
    expect(until, hasLength(3));
  });

  test('weekly BYDAY expands selected weekdays without materializing rows', () {
    final result = CalendarRecurrence.expand(
      event(rule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR'),
      rangeStart: DateTime.utc(2026, 9, 7),
      rangeEnd: DateTime.utc(2026, 9, 14),
    );

    expect(result.map((e) => e.startsAt), [
      DateTime.utc(2026, 9, 7, 8),
      DateTime.utc(2026, 9, 9, 8),
      DateTime.utc(2026, 9, 11, 8),
    ]);
  });

  test('weekly BYDAY does not count days before the series starts', () {
    final result = CalendarRecurrence.expand(
      event(rule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=3'),
      rangeStart: DateTime.utc(2026, 9, 1),
      rangeEnd: DateTime.utc(2026, 9, 15),
    );

    expect(result.map((e) => e.startsAt), [
      DateTime.utc(2026, 9, 2, 8),
      DateTime.utc(2026, 9, 4, 8),
      DateTime.utc(2026, 9, 7, 8),
    ]);
  });

  test('monthly and yearly recurrence advance the series', () {
    final monthly = CalendarRecurrence.expand(
      event(rule: 'FREQ=MONTHLY;INTERVAL=1;COUNT=3'),
      rangeStart: DateTime.utc(2026, 9, 1),
      rangeEnd: DateTime.utc(2026, 12, 1),
    );
    expect(monthly.map((e) => e.startsAt), [
      DateTime.utc(2026, 9, 1, 8),
      DateTime.utc(2026, 10, 1, 8),
      DateTime.utc(2026, 11, 1, 8),
    ]);

    final yearly = CalendarRecurrence.expand(
      event(rule: 'FREQ=YEARLY;COUNT=2'),
      rangeStart: DateTime.utc(2026, 1, 1),
      rangeEnd: DateTime.utc(2028, 1, 2),
    );
    expect(yearly.map((e) => e.startsAt), [
      DateTime.utc(2026, 9, 1, 8),
      DateTime.utc(2027, 9, 1, 8),
    ]);
  });

  test('range boundaries are exclusive', () {
    final beforeStart = CalendarRecurrence.expand(
      event(),
      rangeStart: DateTime.utc(2026, 9, 1, 9),
      rangeEnd: DateTime.utc(2026, 9, 2),
    );
    final atEnd = CalendarRecurrence.expand(
      event(),
      rangeStart: DateTime.utc(2026, 9, 1),
      rangeEnd: DateTime.utc(2026, 9, 1, 8),
    );

    expect(beforeStart, isEmpty);
    expect(atEnd, isEmpty);
  });

  test('non-recurring events use normal range overlap semantics', () {
    final result = CalendarRecurrence.expand(
      event(),
      rangeStart: DateTime.utc(2026, 9, 1, 8, 30),
      rangeEnd: DateTime.utc(2026, 9, 1, 8, 45),
    );
    expect(result, hasLength(1));
  });
}
