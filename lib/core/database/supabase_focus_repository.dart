import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/focus_session_model.dart';
import 'focus_repository_errors.dart';
import 'repositories.dart';

class SupabaseFocusRepository implements FocusRepository {
  SupabaseFocusRepository(this.supabase);
  final SupabaseClient supabase;

  String get _uid {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw const FocusRepositoryException(FocusRepositoryErrorKind.unauthenticated, 'An authenticated user is required for Focus persistence.');
    }
    return user.id;
  }

  @override
  Future<FocusSession> startSession({String? taskId, required int plannedDurationSeconds}) async {
    if (plannedDurationSeconds <= 0) {
      throw const FocusRepositoryException(FocusRepositoryErrorKind.database, 'Planned duration must be greater than zero.');
    }
    try {
      final row = await supabase.from('focus_sessions').insert({
        'user_id': _uid,
        if (taskId != null) 'task_id': taskId,
        'planned_duration_seconds': plannedDurationSeconds,
      }).select().single();
      return FocusSession.fromMap(row['id'] as String, row);
    } on PostgrestException catch (error) {
      throw _mapDatabaseError(error);
    }
  }

  @override
  Future<FocusSession?> getActiveSession() async {
    try {
      final row = await supabase.from('focus_sessions').select().eq('user_id', _uid)
          .inFilter('status', const ['running', 'paused'])
          .order('started_at', ascending: false).maybeSingle();
      return row == null ? null : FocusSession.fromMap(row['id'] as String, row);
    } on PostgrestException catch (error) {
      throw _mapDatabaseError(error);
    } on FormatException catch (error) {
      throw FocusRepositoryException(FocusRepositoryErrorKind.database, 'Malformed Focus session record.', cause: error);
    } on TypeError catch (error) {
      throw FocusRepositoryException(FocusRepositoryErrorKind.database, 'Malformed Focus session record.', cause: error);
    }
  }

  @override
  Future<FocusSession?> getSession(String sessionId) async {
    try {
      final row = await supabase.from('focus_sessions').select().eq('user_id', _uid).eq('id', sessionId).maybeSingle();
      return row == null ? null : FocusSession.fromMap(row['id'] as String, row);
    } on PostgrestException catch (error) {
      throw _mapDatabaseError(error);
    }
  }

  @override
  Future<List<FocusSession>> getSessionHistory({int limit = 100, int offset = 0}) async {
    _validatePage(limit, offset);
    try {
      final rows = await supabase.from('focus_sessions').select().eq('user_id', _uid)
          .order('started_at', ascending: false).range(offset, offset + limit - 1);
      return rows.map((row) => FocusSession.fromMap(row['id'] as String, row)).toList(growable: false);
    } on PostgrestException catch (error) {
      throw _mapDatabaseError(error);
    }
  }

  @override
  Future<List<FocusSession>> getSessionsForTask(String taskId, {int limit = 100, int offset = 0}) async {
    _validatePage(limit, offset);
    try {
      final rows = await supabase.from('focus_sessions').select().eq('user_id', _uid).eq('task_id', taskId)
          .order('started_at', ascending: false).range(offset, offset + limit - 1);
      return rows.map((row) => FocusSession.fromMap(row['id'] as String, row)).toList(growable: false);
    } on PostgrestException catch (error) {
      throw _mapDatabaseError(error);
    }
  }

  @override
  Future<FocusSession> pauseSession(String sessionId) => _transition(sessionId, FocusSessionStatus.paused);
  @override
  Future<FocusSession> resumeSession(String sessionId) => _transition(sessionId, FocusSessionStatus.running);
  @override
  Future<FocusSession> completeSession(String sessionId) => _transition(sessionId, FocusSessionStatus.completed);
  @override
  Future<FocusSession> cancelSession(String sessionId) => _transition(sessionId, FocusSessionStatus.cancelled);

  Future<FocusSession> _transition(String sessionId, FocusSessionStatus status) async {
    try {
      final row = await supabase.from('focus_sessions').update({'status': status.value})
          .eq('id', sessionId).eq('user_id', _uid).select().maybeSingle();
      if (row == null) {
        throw const FocusRepositoryException(FocusRepositoryErrorKind.notFound, 'Focus session was not found or is not accessible.');
      }
      return FocusSession.fromMap(row['id'] as String, row);
    } on FocusRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapDatabaseError(error);
    }
  }

  void _validatePage(int limit, int offset) {
    if (limit < 1 || limit > 500) throw const FocusRepositoryException(FocusRepositoryErrorKind.database, 'Limit must be between 1 and 500.');
    if (offset < 0) throw const FocusRepositoryException(FocusRepositoryErrorKind.database, 'Offset cannot be negative.');
  }

  FocusRepositoryException _mapDatabaseError(PostgrestException error) {
    final message = error.message;
    if (error.code == '23505' && message.contains('focus_sessions_one_active_per_user_idx')) {
      return FocusRepositoryException(FocusRepositoryErrorKind.duplicateActiveSession, 'The user already has an active Focus session.', cause: error);
    }
    if (message.contains('Focus session is already') || message.contains('Invalid focus session transition') || message.contains('Terminal focus sessions cannot change lifecycle state')) {
      return FocusRepositoryException(FocusRepositoryErrorKind.invalidTransition, message, cause: error);
    }
    if (message.contains('Focus task does not exist') || message.contains('does not belong to the session owner')) {
      return FocusRepositoryException(FocusRepositoryErrorKind.permissionDenied, message, cause: error);
    }
    if (error.code == '42501') return FocusRepositoryException(FocusRepositoryErrorKind.permissionDenied, 'Permission denied for Focus data.', cause: error);
    return FocusRepositoryException(FocusRepositoryErrorKind.database, message, cause: error);
  }
}
