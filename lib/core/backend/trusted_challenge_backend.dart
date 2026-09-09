import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';

abstract interface class TrustedChallengeBackend {
  Future<DailyChallengeResult> getOrAssignDailyChallenge();
  Future<CompleteChallengeResult> completeChallenge({String? idempotencyKey});
}

abstract interface class TrustedCallableClient {
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data);
}

class SupabaseTrustedCallableClient implements TrustedCallableClient {
  SupabaseTrustedCallableClient(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) async {
    try {
      final response = await _supabase.functions.invoke(name, body: data);
      if (response.data is! Map) throw const TrustedBackendException(TrustedBackendErrorCode.internal, 'The backend returned an invalid response.');
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionsHttpError catch (error) {
      throw mapHttpStatus(error.status);
    } on FunctionsRelayError {
      throw const TrustedBackendException(TrustedBackendErrorCode.unavailable, 'The service is temporarily unavailable.');
    } on FunctionsFetchError {
      throw const TrustedBackendException(TrustedBackendErrorCode.unavailable, 'The service is temporarily unavailable.');
    } on TrustedBackendException {
      rethrow;
    } catch (_) {
      throw const TrustedBackendException(TrustedBackendErrorCode.unavailable, 'The service is temporarily unavailable.');
    }
  }

  static TrustedBackendException mapHttpStatus(int status) {
    switch (status) {
      case 401: return const TrustedBackendException(TrustedBackendErrorCode.unauthenticated, 'Authentication is required.');
      case 403: return const TrustedBackendException(TrustedBackendErrorCode.permissionDenied, 'You do not have permission to perform this action.');
      case 404: return const TrustedBackendException(TrustedBackendErrorCode.notFound, 'The requested resource was not found.');
      case 409: return const TrustedBackendException(TrustedBackendErrorCode.alreadyCompleted, 'This challenge has already been completed.');
      case 422: return const TrustedBackendException(TrustedBackendErrorCode.failedPrecondition, 'The request cannot be completed in the current state.');
      case 429: return const TrustedBackendException(TrustedBackendErrorCode.unavailable, 'The service is temporarily unavailable.');
      default: return const TrustedBackendException(TrustedBackendErrorCode.internal, 'Something went wrong on the server.');
    }
  }
}

class DailyChallengeResult {
  const DailyChallengeResult({required this.date, required this.challengeId, required this.completed, required this.assignedAt});
  final String date;
  final String challengeId;
  final bool completed;
  final DateTime assignedAt;
}

class CompleteChallengeResult {
  const CompleteChallengeResult({required this.activityCompleted, required this.alreadyCompleted, required this.xpAwarded, required this.previousXP, required this.newXP, required this.previousStreak, required this.newStreak, required this.longestStreak, required this.previousLevel, required this.newLevel, required this.leveledUp, required this.newAchievements, this.challengeId});
  final bool activityCompleted;
  final bool alreadyCompleted;
  final int xpAwarded;
  final int previousXP;
  final int newXP;
  final int previousStreak;
  final int newStreak;
  final int longestStreak;
  final int previousLevel;
  final int newLevel;
  final bool leveledUp;
  final List<String> newAchievements;
  final String? challengeId;
}

class TrustedBackendException implements Exception {
  const TrustedBackendException(this.code, this.message);
  final TrustedBackendErrorCode code;
  final String message;
  @override
  String toString() => 'TrustedBackendException(${code.name}): $message';
}

enum TrustedBackendErrorCode { unauthenticated, permissionDenied, notFound, alreadyCompleted, failedPrecondition, unavailable, invalidArgument, internal }

class SupabaseTrustedChallengeBackend implements TrustedChallengeBackend {
  SupabaseTrustedChallengeBackend(this._client, this._authService);
  final TrustedCallableClient _client;
  final AuthService _authService;

  @override
  Future<DailyChallengeResult> getOrAssignDailyChallenge() async {
    await _requireAuthenticated();
    return _parseDailyChallenge(await _client.call('get-or-assign-daily-challenge', const <String, dynamic>{}));
  }

  @override
  Future<CompleteChallengeResult> completeChallenge({String? idempotencyKey}) async {
    await _requireAuthenticated();
    final data = idempotencyKey == null ? const <String, dynamic>{} : <String, dynamic>{'idempotencyKey': idempotencyKey};
    return _parseCompletion(await _client.call('complete-challenge', data));
  }

  Future<void> _requireAuthenticated() async {
    final state = await _authService.authStateChanges.first;
    if (state.status != AuthStatus.authenticated) throw const TrustedBackendException(TrustedBackendErrorCode.unauthenticated, 'Authentication is required.');
  }

  DailyChallengeResult _parseDailyChallenge(Map<String, dynamic> data) {
    final date = data['date'];
    final challengeId = data['challengeId'];
    final completed = data['completed'];
    final assignedAt = _date(data['assignedAt']);
    if (date is! String || challengeId is! String || challengeId.isEmpty || completed is! bool || assignedAt == null) throw const TrustedBackendException(TrustedBackendErrorCode.internal, 'The backend returned an invalid daily challenge.');
    return DailyChallengeResult(date: date, challengeId: challengeId, completed: completed, assignedAt: assignedAt);
  }

  CompleteChallengeResult _parseCompletion(Map<String, dynamic> data) {
    final completed = data['completed'];
    final alreadyCompleted = data['alreadyCompleted'];
    if (completed is! bool || alreadyCompleted is! bool) throw const TrustedBackendException(TrustedBackendErrorCode.internal, 'The backend returned an invalid completion result.');
    return CompleteChallengeResult(
      activityCompleted: completed,
      alreadyCompleted: alreadyCompleted,
      xpAwarded: _int(data, 'xpAwarded'),
      previousXP: _int(data, 'previousXP'),
      newXP: _int(data, 'currentXP'),
      previousStreak: _int(data, 'previousStreak'),
      newStreak: _int(data, 'currentStreak'),
      longestStreak: _int(data, 'longestStreak'),
      previousLevel: _int(data, 'previousLevel'),
      newLevel: _int(data, 'newLevel'),
      leveledUp: _bool(data, 'leveledUp'),
      newAchievements: _strings(data, 'newAchievements'),
      challengeId: data['challengeId'] as String?,
    );
  }

  int _int(Map<String, dynamic> data, String key) => (data[key] as num?)?.toInt() ?? 0;
  bool _bool(Map<String, dynamic> data, String key) => data[key] as bool? ?? false;
  List<String> _strings(Map<String, dynamic> data, String key) => data[key] is List ? (data[key] as List).whereType<String>().toList(growable: false) : const <String>[];

  DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is Map && value['iso'] is String) return DateTime.tryParse(value['iso'] as String);
    return DateTime.tryParse(value.toString());
  }
}

/// Compatibility name for older application-layer tests and contracts.
class FirebaseCallableChallengeBackend extends SupabaseTrustedChallengeBackend {
  FirebaseCallableChallengeBackend(super.client, super.authService);
}
