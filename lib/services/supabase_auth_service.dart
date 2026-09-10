import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../core/auth/auth_service.dart';
import '../core/backend/trusted_account_backend.dart';
import '../core/errors/app_error.dart';

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._supabase, this._accountBackend);

  final supabase.SupabaseClient _supabase;
  final TrustedAccountBackend _accountBackend;

  @override
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange.map((event) => _mapUser(event.session?.user ?? _supabase.auth.currentUser));

  @override
  String? get pendingEmail => _supabase.auth.currentUser?.email;

  AuthState _mapUser(supabase.User? user) {
    if (user == null) return const AuthState(status: AuthStatus.unauthenticated);
    final verified = user.emailConfirmedAt != null;
    return AuthState(status: verified ? AuthStatus.authenticated : AuthStatus.authenticatedUnverified, uid: user.id);
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
    if (message.contains('email not confirmed')) return 'email-not-verified';
    if (message.contains('invalid email')) return 'invalid-email';
    if (message.contains('token') && (message.contains('expired') || message.contains('invalid'))) return 'invalid-otp';
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
    return _mapUser(response.user);
  });

  @override
  Future<AuthState> registerWithEmail({required String email, required String password}) async => _guard(() async {
    final response = await _supabase.auth.signUp(email: email, password: password);
    return _mapUser(response.user);
  });

  @override
  Future<void> sendEmailVerification() => _guard(() async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.email == null) throw const AuthFailure('session-expired');
    await _supabase.auth.resend(type: supabase.OtpType.signup, email: user.email!);
  });

  @override
  Future<AuthState> verifySignUpCode({required String email, required String code}) => _guard(() async {
    final response = await _supabase.auth.verifyOTP(type: supabase.OtpType.signup, email: email, token: code.trim());
    return _mapUser(response.user);
  });

  @override
  Future<bool> reloadVerificationState() => _guard(() async {
    final response = await _supabase.auth.getUser();
    return response.user?.emailConfirmedAt != null;
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
