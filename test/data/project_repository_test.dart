import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/database/repositories.dart';
import 'package:pulse/models/project_model.dart';

class FakeProjectRepository implements ProjectRepository {
  FakeProjectRepository(this._projects);
  final List<Project> _projects;

  @override
  Future<List<Project>> getProjects({required String uid}) async =>
      _projects.where((project) => project.userId == uid).toList(growable: false);

  @override
  Future<Project?> getProject({required String uid, required String projectId}) async =>
      _projects.where((project) => project.userId == uid && project.id == projectId).firstOrNull;

  @override
  Future<Project> createProject({required String uid, required String name, String? description}) async {
    final project = Project(
      id: 'created-${_projects.length + 1}',
      userId: uid,
      name: name.trim(),
      description: description?.trim(),
    );
    _projects.add(project);
    return project;
  }

  @override
  Future<Project> updateProject({required String projectId, String? name, String? description, ProjectStatus? status}) async {
    final index = _projects.indexWhere((project) => project.id == projectId);
    if (index < 0) throw StateError('Project not found');
    final current = _projects[index];
    final updated = Project(
      id: current.id,
      userId: current.userId,
      name: name?.trim() ?? current.name,
      description: description?.trim() ?? current.description,
      status: status ?? current.status,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    _projects[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteProject({required String projectId}) async {
    _projects.removeWhere((project) => project.id == projectId);
  }
}

void main() {
  test('project repository contract supports create, list, open, update and delete', () async {
    final repository = FakeProjectRepository(<Project>[]);

    final created = await repository.createProject(
      uid: 'user-1',
      name: '  Build Pulse  ',
      description: '  first project  ',
    );

    expect(created.name, 'Build Pulse');
    expect(created.description, 'first project');
    expect((await repository.getProjects(uid: 'user-1')).length, 1);
    expect((await repository.getProject(uid: 'user-1', projectId: created.id))?.name, 'Build Pulse');

    final updated = await repository.updateProject(
      projectId: created.id,
      name: 'Pulse 2A',
      status: ProjectStatus.completed,
    );
    expect(updated.name, 'Pulse 2A');
    expect(updated.status, ProjectStatus.completed);

    await repository.deleteProject(projectId: created.id);
    expect(await repository.getProject(uid: 'user-1', projectId: created.id), isNull);
  });
}
