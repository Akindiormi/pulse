import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/auth/auth_service.dart';
import '../../../models/calendar_event_model.dart';
import '../../../models/task_model.dart';
import 'calendar_recurrence.dart';

class CalendarRange {
  const CalendarRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is CalendarRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

Future<String> _authenticatedUid(Ref ref) async {
  final state = await ref.read(authServiceProvider).authStateChanges.first;
  if (state.status != AuthStatus.authenticated || state.uid == null) {
    throw StateError('Sign in to use Calendar.');
  }
  return state.uid!;
}

final calendarEventsProvider =
    FutureProvider.family<List<CalendarEvent>, CalendarRange>((ref, range) async {
  final uid = await _authenticatedUid(ref);
  final stored = await ref.read(calendarRepositoryProvider).getEvents(
        uid: uid,
        rangeStart: range.start,
        rangeEnd: range.end,
      );

  final expanded = <CalendarEvent>[];
  for (final event in stored) {
    expanded.addAll(CalendarRecurrence.expand(
      event,
      rangeStart: range.start,
      rangeEnd: range.end,
    ));
  }

  expanded.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return expanded;
});

final calendarTasksProvider = FutureProvider<List<Task>>((ref) async {
  final uid = await _authenticatedUid(ref);
  return ref.read(taskRepositoryProvider).getTasks(uid: uid);
});
