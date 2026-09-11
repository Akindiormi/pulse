import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/models/task_model.dart';

void main() {
  group('Task', () {
    test('parses a Supabase row', () {
      final task = Task.fromMap('task-1', {
        'id': 'task-1',
        'user_id': 'user-1',
        'title': 'finish pharmacology assignment',
        'status': 'todo',
        'due_date': '2026-09-09',
        'priority': 2,
      });

      expect(task.id, 'task-1');
      expect(task.userId, 'user-1');
      expect(task.title, 'finish pharmacology assignment');
      expect(task.status, TaskStatus.todo);
      expect(task.priority, 2);
      expect(task.taskSeriesId, isNull);
      expect(task.occurrenceKey, isNull);
      expect(task.firstCompletedAt, isNull);
      expect(task.isOpen, isTrue);
    });

    test('parses lifecycle fields while preserving normal task fields', () {
      final occurrence = DateTime.parse('2026-09-14T08:00:00Z');
      final firstCompleted = DateTime.parse('2026-09-14T08:05:00Z');
      final task = Task.fromMap('task-2', {
        'user_id': 'user-1',
        'title': 'gym',
        'status': 'completed',
        'due_date': '2026-09-14',
        'due_time': '08:00:00',
        'project_id': 'project-1',
        'milestone_id': 'milestone-1',
        'priority': 1,
        'task_series_id': 'series-1',
        'occurrence_key': occurrence.toIso8601String(),
        'first_completed_at': firstCompleted.toIso8601String(),
        'completed_at': firstCompleted.toIso8601String(),
      });

      expect(task.taskSeriesId, 'series-1');
      expect(task.occurrenceKey, occurrence);
      expect(task.firstCompletedAt, firstCompleted);
      expect(task.completedAt, firstCompleted);
      expect(task.projectId, 'project-1');
      expect(task.milestoneId, 'milestone-1');
      expect(task.priority, 1);
    });

    test('recognises completed tasks', () {
      final task = Task.fromMap('task-3', {
        'user_id': 'user-1',
        'title': 'done',
        'status': 'completed',
        'completed_at': '2026-09-09T10:00:00Z',
      });

      expect(task.isCompleted, isTrue);
      expect(task.isOpen, isFalse);
    });

    test('unknown status safely falls back to todo', () {
      final task = Task.fromMap('task-4', {'user_id': 'user-1', 'title': 'new', 'status': 'future_status'});
      expect(task.status, TaskStatus.todo);
    });

    test('copyWith can reopen without erasing historical completion identity', () {
      final firstCompleted = DateTime.parse('2026-09-09T10:00:00Z');
      final task = Task(
        id: 'task-5',
        userId: 'user-1',
        title: 'done',
        status: TaskStatus.completed,
        firstCompletedAt: firstCompleted,
        completedAt: firstCompleted,
      );

      final reopened = task.copyWith(status: TaskStatus.todo, clearCompletedAt: true);

      expect(reopened.status, TaskStatus.todo);
      expect(reopened.completedAt, isNull);
      expect(reopened.firstCompletedAt, firstCompleted);
    });
  });

  group('TaskSeries', () {
    test('parses the exact database recurrence contract', () {
      final startsAt = DateTime.parse('2026-09-14T08:00:00Z');
      final series = TaskSeries.fromMap('series-1', {
        'user_id': 'user-1',
        'title': 'gym',
        'recurrence_type': 'weekly',
        'recurrence_interval': 2,
        'timezone': 'Africa/Lagos',
        'starts_at': startsAt.toIso8601String(),
        'until_at': '2026-12-31T23:59:59Z',
        'occurrence_count': 8,
        'is_active': true,
      });

      expect(series.id, 'series-1');
      expect(series.recurrenceType, TaskRecurrenceType.weekly);
      expect(series.recurrenceInterval, 2);
      expect(series.timezone, 'Africa/Lagos');
      expect(series.startsAt, startsAt);
      expect(series.occurrenceCount, 8);
      expect(series.isActive, isTrue);
    });
  });

  group('TaskReopenResult', () {
    test('parses authoritative reopen response', () {
      final firstCompleted = DateTime.parse('2026-09-09T10:00:00Z');
      final result = TaskReopenResult.fromMap({
        'reopened': true,
        'alreadyOpen': false,
        'taskId': 'task-1',
        'status': 'todo',
        'firstCompletedAt': firstCompleted.toIso8601String(),
      });

      expect(result.reopened, isTrue);
      expect(result.alreadyOpen, isFalse);
      expect(result.taskId, 'task-1');
      expect(result.status, TaskStatus.todo);
      expect(result.firstCompletedAt, firstCompleted);
    });
  });

  group('TaskCompletionResult', () {
    test('parses backend completion response', () {
      final firstCompleted = DateTime.parse('2026-09-09T10:00:00Z');
      final result = TaskCompletionResult.fromMap({
        'completed': true,
        'alreadyCompleted': false,
        'alreadyRewarded': true,
        'taskId': 'task-1',
        'eventId': 'event-1',
        'xpAwarded': 0,
        'newXP': 110,
        'newLevel': 2,
        'newStreak': 3,
        'longestStreak': 5,
        'totalActivities': 9,
        'firstCompletedAt': firstCompleted.toIso8601String(),
      });

      expect(result.completed, isTrue);
      expect(result.alreadyRewarded, isTrue);
      expect(result.eventId, 'event-1');
      expect(result.xpAwarded, 0);
      expect(result.firstCompletedAt, firstCompleted);
      expect(result.newStreak, 3);
      expect(result.totalActivities, 9);
    });
  });
}
