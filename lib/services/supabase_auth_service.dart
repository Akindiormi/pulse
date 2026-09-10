import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../core/auth/auth_service.dart';
import '../core/backend/trusted_account_backend.dart';
import '../core/errors/app_error.dart';

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._supabase, this._accountBackend);

  final supabase.SupabaseClient _supabase;
  final TrustedAccountBackend _accountBackend;

  @override
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange
      .map((event) => _mapUser(event.session?.user, session: event.session));

  AuthState _mapUser(supabase.User? user, {supabase.Session? session}) {
    if (user == null || session == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    return AuthState(status: AuthStatus.authenticated, uid: user.id);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on supabase.AuthException catch (e) {
      throw AuthFailure(_mapErrorCode(e), debugMessage: 'AuthException(status: ${e.statusCode}): ${e.message}');
    } on supabase.PostgrestException catch (e) {
      throw AuthFailure(e.code ?? 'service-unavailable', debugMessage: 'PostgrestException(code: ${e.code}): ${e.message} | details: ${e.details}');
    } catch (e) {
      throw AuthFailure('auth-error', debugMessage: e.toString());
    }
  }

  String _mapErrorCode(supabase.AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('already registered')) return 'email-already-in-use';
    if (message.contains('invalid login') || message.contains('invalid credentials')) return 'invalid-credential';
    if (message.contains('invalid email')) return 'invalid-email';
    if (message.contains('password')) return 'weak-password';
    if (message.contains('rate limit')) return 'too-many-requests';
    return 'auth-error';
  }

  @override
  Future<AuthState> signInWithGoogle() async => throw const AuthFailure('provider-not-supported');

  @override
  Future<AuthState> signInWithApple() async => throw const AuthFailure('provider-not-supported');

  @override
  Future<AuthState> signInWithEmail({required String email, required String password}) async => _guard(() async {
    final response = await _supabase.auth.signInWithPassword(email: email, password: password);
    return _mapUser(response.user, session: response.session);
  });

  @override
  Future<AuthState> registerWithEmail({required String email, required String password}) async => _guard(() async {
    final response = await _supabase.auth.signUp(email: email, password: password);
    if (response.session == null || response.user == null) {
      throw const AuthFailure('signup-session-unavailable', debugMessage: 'Supabase signup returned no authenticated session. Confirm email must be disabled for the Pulse signup flow.');
    }
    return _mapUser(response.user, session: response.session);
  });

  @override
  Future<void> sendPasswordResetEmail({required String email}) => _guard(() => _supabase.auth.resetPasswordForEmail(email));

  @override
  Future<void> signOut() => _supabase.auth.signOut();

  @override
  Future<void> deleteAccount() async {
    await _accountBackend.deleteAccountData();
    await _supabase.auth.signOut();
  }
}
