import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/models/milestone_model.dart';

void main() {
  test('parses milestone fields', () {
    final milestone = Milestone.fromMap('m1', {
      'project_id': 'p1',
      'user_id': 'u1',
      'name': 'Launch',
      'status': 'active',
      'due_date': '2026-09-20',
    });
    expect(milestone.id, 'm1');
    expect(milestone.projectId, 'p1');
    expect(milestone.userId, 'u1');
    expect(milestone.name, 'Launch');
    expect(milestone.dueDate, DateTime.parse('2026-09-20'));
  });

  test('progress handles empty and completed milestones', () {
    expect(const ProgressStats(completed: 0, total: 0).percent, 0);
    expect(const ProgressStats(completed: 2, total: 4).percent, 50);
    expect(const ProgressStats(completed: 4, total: 4).percent, 100);
  });
}
