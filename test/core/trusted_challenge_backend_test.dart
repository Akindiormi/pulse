import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/auth/auth_service.dart';
import 'package:pulse/core/backend/trusted_challenge_backend.dart';

void main() {
  group('FirebaseCallableChallengeBackend', () {
    test('rejects unauthenticated calls before transport', () async {
      final client = FakeCallableClient();
      final backend = FirebaseCallableChallengeBackend(client, const FakeAuthService(AuthState(status: AuthStatus.unauthenticated)));

      await expectLater(backend.completeChallenge(), throwsA(predicate<TrustedBackendException>((e) => e.code == TrustedBackendErrorCode.unauthenticated)));
      expect(client.calls, isEmpty);
    });

    test('uses authenticated Firebase Auth state without sending a uid', () async {
      final client = FakeCallableClient(response: {
        'completed': true,
        'alreadyCompleted': false,
        'challengeId': 'challenge-1',
        'xpAwarded': 35,
        'previousXP': 0,
        'currentXP': 35,
        'previousStreak': 0,
        'currentStreak': 1,
        'longestStreak': 1,
        'previousLevel': 1,
        'newLevel': 1,
        'leveledUp': false,
        'newAchievements': ['FIRST_STEP'],
      });
      final backend = FirebaseCallableChallengeBackend(client, const FakeAuthService(AuthState(status: AuthStatus.authenticated, uid: 'uid-that-must-not-be-sent')));

      final result = await backend.completeChallenge();

      expect(result.newXP, 35);
      expect(result.newStreak, 1);
      expect(result.newAchievements, ['FIRST_STEP']);
      expect(client.calls.single.name, 'completeChallenge');
      expect(client.calls.single.data, isEmpty);
      expect(client.calls.single.data.containsKey('uid'), false);
    });

    test('sends only optional retry correlation key when supplied', () async {
      final client = FakeCallableClient(response: {
        'completed': false,
        'alreadyCompleted': true,
        'challengeId': 'challenge-1',
        'xpAwarded': 0,
        'previousXP': 35,
        'currentXP': 35,
        'previousStreak': 1,
        'currentStreak': 1,
        'longestStreak': 1,
        'previousLevel': 1,
        'newLevel': 1,
        'leveledUp': false,
        'newAchievements': [],
      });
      final backend = FirebaseCallableChallengeBackend(client, const FakeAuthService(AuthState(status: AuthStatus.authenticated)));

      final result = await backend.completeChallenge(idempotencyKey: 'retry-1');

      expect(result.alreadyCompleted, true);
      expect(client.calls.single.data, {'idempotencyKey': 'retry-1'});
    });

    test('parses backend daily assignment and never creates it client-side', () async {
      final client = FakeCallableClient(response: {
        'date': '2026-09-02',
        'challengeId': 'challenge-1',
        'completed': false,
        'assignedAt': '2026-09-02T10:00:00.000Z',
      });
      final backend = FirebaseCallableChallengeBackend(client, const FakeAuthService(AuthState(status: AuthStatus.authenticated)));

      final result = await backend.getOrAssignDailyChallenge();

      expect(result.date, '2026-09-02');
      expect(result.challengeId, 'challenge-1');
      expect(result.assignedAt.toUtc(), DateTime.utc(2026, 9, 2, 10));
      expect(client.calls.single.name, 'getOrAssignDailyChallenge');
      expect(client.calls.single.data, isEmpty);
    });

    test('maps Firebase callable errors into safe domain errors', () {
      final cases = <String, TrustedBackendErrorCode>{
        'unauthenticated': TrustedBackendErrorCode.unauthenticated,
        'permission-denied': TrustedBackendErrorCode.permissionDenied,
        'not-found': TrustedBackendErrorCode.notFound,
        'failed-precondition': TrustedBackendErrorCode.failedPrecondition,
        'invalid-argument': TrustedBackendErrorCode.invalidArgument,
        'unavailable': TrustedBackendErrorCode.unavailable,
        'deadline-exceeded': TrustedBackendErrorCode.unavailable,
        'already-exists': TrustedBackendErrorCode.alreadyCompleted,
        'internal': TrustedBackendErrorCode.internal,
      };
      for (final entry in cases.entries) {
        final mapped = FirebaseTrustedCallableClient.mapError(FirebaseFunctionsException(code: entry.key, message: 'sensitive backend detail'));
        expect(mapped.code, entry.value);
        expect(mapped.message.contains('sensitive'), false);
      }
    });
  });
}

class FakeCallableClient implements TrustedCallableClient {
  FakeCallableClient({this.response = const <String, dynamic>{}});
  final Map<String, dynamic> response;
  final calls = <_Call>[];

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) async {
    calls.add(_Call(name, Map<String, dynamic>.from(data)));
    return response;
  }
}

class _Call {
  const _Call(this.name, this.data);
  final String name;
  final Map<String, dynamic> data;
}

class FakeAuthService implements AuthService {
  const FakeAuthService(this.state);
  final AuthState state;

  @override
  Stream<AuthState> get authStateChanges => Stream.value(state);
  @override Future<AuthState> signInWithGoogle() => throw UnimplementedError();
  @override Future<AuthState> signInWithApple() => throw UnimplementedError();
  @override Future<AuthState> signInWithEmail({required String email, required String password}) => throw UnimplementedError();
  @override Future<AuthState> registerWithEmail({required String email, required String password}) => throw UnimplementedError();
  @override Future<void> sendEmailVerification() => throw UnimplementedError();
  @override Future<void> sendPasswordResetEmail({required String email}) => throw UnimplementedError();
  @override Future<bool> reloadVerificationState() async => state.status == AuthStatus.authenticated;
  @override Future<void> signOut() => throw UnimplementedError();
  @override Future<void> deleteAccount() => throw UnimplementedError();
}
