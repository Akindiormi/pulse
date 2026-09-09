import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/database/repositories.dart';
import 'package:pulse/models/calendar_event_model.dart';

class FakeCalendarRepository implements CalendarRepository {
  final events = <CalendarEvent>[];
  final links = <String, List<String>>{};

  @override
  Future<List<CalendarEvent>> getEvents({required String uid, required DateTime rangeStart, required DateTime rangeEnd}) async => events.where((event) => event.userId == uid && (event.isRecurring || event.endsAt.isAfter(rangeStart)) && event.startsAt.isBefore(rangeEnd)).toList();

  @override
  Future<CalendarEvent> createEvent({required String uid, required String title, String? description, required DateTime startsAt, required DateTime endsAt, bool allDay = false, required String timezone, String? recurrenceRule, String? taskId}) async {
    final event = CalendarEvent(id: 'event-${events.length + 1}', userId: uid, title: title, description: description, startsAt: startsAt, endsAt: endsAt, allDay: allDay, timezone: timezone, recurrenceRule: recurrenceRule, taskIds: taskId == null ? const [] : [taskId]);
    events.add(event);
    return event;
  }

  @override
  Future<CalendarEvent> updateEvent({required String eventId, String? title, String? description, DateTime? startsAt, DateTime? endsAt, bool? allDay, String? timezone, String? recurrenceRule}) async => events.firstWhere((event) => event.id == eventId).copyWith(title: title, description: description, startsAt: startsAt, endsAt: endsAt, allDay: allDay, timezone: timezone, recurrenceRule: recurrenceRule);

  @override Future<void> deleteEvent({required String eventId}) async => events.removeWhere((event) => event.id == eventId);
  @override Future<void> linkTask({required String taskId, required String eventId}) async => links.putIfAbsent(eventId, () => []).add(taskId);
  @override Future<void> unlinkTask({required String taskId, required String eventId}) async => links[eventId]?.remove(taskId);
}

void main() {
  test('calendar repository contract keeps task and event independent', () async {
    final repo = FakeCalendarRepository();
    final event = await repo.createEvent(
      uid: 'user-1',
      title: 'Study block',
      startsAt: DateTime.utc(2026, 9, 10, 8),
      endsAt: DateTime.utc(2026, 9, 10, 9),
      timezone: 'Africa/Lagos',
      taskId: 'task-1',
    );

    expect(event.taskIds, ['task-1']);
    expect((await repo.getEvents(uid: 'user-1', rangeStart: DateTime.utc(2026, 9, 10), rangeEnd: DateTime.utc(2026, 9, 11))).single.id, event.id);

    await repo.unlinkTask(taskId: 'task-1', eventId: event.id);
    expect(repo.links[event.id], isEmpty);
    expect(repo.events.single.id, event.id);

    await repo.deleteEvent(eventId: event.id);
    expect(repo.events, isEmpty);
  });

  test('recurring events remain visible when their series starts before the requested range', () async {
    final repo = FakeCalendarRepository();
    await repo.createEvent(
      uid: 'user-1',
      title: 'Daily review',
      startsAt: DateTime.utc(2026, 9, 1, 8),
      endsAt: DateTime.utc(2026, 9, 1, 9),
      timezone: 'Africa/Lagos',
      recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
    );

    final events = await repo.getEvents(uid: 'user-1', rangeStart: DateTime.utc(2026, 9, 10), rangeEnd: DateTime.utc(2026, 9, 11));
    expect(events, hasLength(1));
    expect(events.single.isRecurring, isTrue);
  });
}
