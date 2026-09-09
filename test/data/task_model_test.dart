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
      expect(task.isOpen, isTrue);
    });

    test('recognises completed tasks', () {
      final task = Task.fromMap('task-2', {
        'user_id': 'user-1',
        'title': 'done',
        'status': 'completed',
        'completed_at': '2026-09-09T10:00:00Z',
      });

      expect(task.isCompleted, isTrue);
      expect(task.isOpen, isFalse);
    });

    test('unknown status safely falls back to todo', () {
      final task = Task.fromMap('task-3', {'user_id': 'user-1', 'title': 'new', 'status': 'future_status'});
      expect(task.status, TaskStatus.todo);
    });
  });

  group('TaskCompletionResult', () {
    test('parses backend completion response', () {
      final result = TaskCompletionResult.fromMap({
        'completed': true,
        'alreadyCompleted': false,
        'taskId': 'task-1',
        'eventId': 'event-1',
        'xpAwarded': 10,
        'newXP': 110,
        'newLevel': 2,
        'newStreak': 3,
        'longestStreak': 5,
        'totalActivities': 9,
      });

      expect(result.completed, isTrue);
      expect(result.eventId, 'event-1');
      expect(result.xpAwarded, 10);
      expect(result.newStreak, 3);
      expect(result.totalActivities, 9);
    });
  });
}
