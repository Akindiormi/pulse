import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/models/calendar_event_model.dart';

void main() {
  test('parses database fields including recurrence and task links', () {
    final event = CalendarEvent.fromMap('event-1', {
      'user_id': 'user-1',
      'title': 'Lecture',
      'description': 'Pharmacology lecture',
      'starts_at': '2026-09-10T08:00:00Z',
      'ends_at': '2026-09-10T10:00:00Z',
      'all_day': false,
      'timezone': 'Africa/Lagos',
      'recurrence_rule': 'FREQ=WEEKLY;INTERVAL=1',
      'task_ids': ['task-1'],
    });

    expect(event.id, 'event-1');
    expect(event.timezone, 'Africa/Lagos');
    expect(event.isRecurring, isTrue);
    expect(event.taskIds, ['task-1']);
  });

  test('toMap preserves the scheduling contract', () {
    final event = CalendarEvent(
      id: 'event-1',
      userId: 'user-1',
      title: 'Focus block',
      startsAt: DateTime.utc(2026, 9, 10, 8),
      endsAt: DateTime.utc(2026, 9, 10, 9),
      timezone: 'Africa/Lagos',
      recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
    );

    final map = event.toMap();
    expect(map['user_id'], 'user-1');
    expect(map['timezone'], 'Africa/Lagos');
    expect(map['recurrence_rule'], 'FREQ=DAILY;INTERVAL=1');
    expect(map['starts_at'], '2026-09-10T08:00:00.000Z');
  });

  test('copyWith changes only requested fields', () {
    final event = CalendarEvent(
      id: 'event-1',
      userId: 'user-1',
      title: 'Old',
      startsAt: DateTime.utc(2026, 9, 10, 8),
      endsAt: DateTime.utc(2026, 9, 10, 9),
    );

    final updated = event.copyWith(title: 'New', taskIds: ['task-1']);
    expect(updated.title, 'New');
    expect(updated.startsAt, event.startsAt);
    expect(updated.taskIds, ['task-1']);
  });
}
