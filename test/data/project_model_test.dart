import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/models/project_model.dart';

void main() {
  group('Project', () {
    test('parses a Supabase row', () {
      final project = Project.fromMap('project-1', {
        'user_id': 'user-1',
        'name': 'Pharmacology SIWES',
        'description': 'Plan the placement',
        'status': 'active',
        'created_at': '2026-09-09T10:00:00Z',
        'updated_at': '2026-09-09T11:00:00Z',
      });

      expect(project.id, 'project-1');
      expect(project.userId, 'user-1');
      expect(project.name, 'Pharmacology SIWES');
      expect(project.status, ProjectStatus.active);
      expect(project.createdAt, DateTime.parse('2026-09-09T10:00:00Z'));
    });

    test('supports camelCase maps and defaults unknown status to active', () {
      final project = Project.fromMap('project-2', {
        'userId': 'user-2',
        'name': 'Build Pulse',
        'status': 'future_status',
      });

      expect(project.userId, 'user-2');
      expect(project.status, ProjectStatus.active);
      expect(project.description, isNull);
    });
  });
}
