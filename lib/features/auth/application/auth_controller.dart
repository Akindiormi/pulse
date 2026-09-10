import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_error.dart';

enum AuthFlowStatus { idle, loading, success, error, cancelled, verificationRequired }

class AuthController extends Notifier<AuthControllerState> {
  @override AuthControllerState build() => const AuthControllerState();

  Future<void> _reportAuthFailure(String flow, Object error, StackTrace stack) async {
    final code = error is AuthFailure ? error.code : 'unknown';
    // Crashlytics gets the *real* underlying error/message so a generic
    // "something went wrong" in the UI is always debuggable from the
    // Firebase console, regardless of Supabase dashboard access.
    await ref.read(crashReporterProvider).recordError(error, stack, reason: 'auth_failed:$flow');
    await ref.read(analyticsServiceProvider).logAuthFailed(flow, code: code);
  }

  Future<AuthState?> signIn(String email, String password) async {
    if (state.loading) return null; state = state.copyWith(status: AuthFlowStatus.loading, error: null);
    try { final result = await ref.read(authServiceProvider).signInWithEmail(email: email.trim(), password: password); state = state.copyWith(status: result.status == AuthStatus.authenticatedUnverified ? AuthFlowStatus.verificationRequired : AuthFlowStatus.success); return result; }
    catch (e, s) { final error = ErrorMessageMapper.from(e, kind: AppErrorKind.auth); state = state.copyWith(status: error.cancelled ? AuthFlowStatus.cancelled : AuthFlowStatus.error, error: error); await _reportAuthFailure('email_sign_in', e, s); return null; }
  }
  Future<AuthState?> signUp(String email, String password) async {
    if (state.loading) return null; state = state.copyWith(status: AuthFlowStatus.loading, error: null);
    try { final result = await ref.read(authServiceProvider).registerWithEmail(email: email.trim(), password: password); state = state.copyWith(status: result.status == AuthStatus.authenticatedUnverified ? AuthFlowStatus.verificationRequired : AuthFlowStatus.success); return result; }
    catch (e, s) { final error = ErrorMessageMapper.from(e, kind: AppErrorKind.auth); state = state.copyWith(status: error.cancelled ? AuthFlowStatus.cancelled : AuthFlowStatus.error, error: error); await _reportAuthFailure('email_sign_up', e, s); return null; }
  }
  Future<AppError?> resetPassword(String email) async {
    if (state.loading) return null; state = state.copyWith(status: AuthFlowStatus.loading, error: null);
    try { await ref.read(authServiceProvider).sendPasswordResetEmail(email: email.trim()); state = state.copyWith(status: AuthFlowStatus.success); return null; }
    catch (e, s) { final error = ErrorMessageMapper.from(e, kind: AppErrorKind.auth); state = state.copyWith(status: error.cancelled ? AuthFlowStatus.cancelled : AuthFlowStatus.error, error: error); await _reportAuthFailure('password_reset', e, s); return error; }
  }
  void clearError() => state = state.copyWith(error: null, status: AuthFlowStatus.idle);
}
class AuthControllerState {
  const AuthControllerState({this.status = AuthFlowStatus.idle, this.error}); final AuthFlowStatus status; final AppError? error; bool get loading => status == AuthFlowStatus.loading;
  AuthControllerState copyWith({AuthFlowStatus? status, AppError? error, bool clearError = false}) => AuthControllerState(status: status ?? this.status, error: clearError ? null : (error ?? this.error));
}
final authControllerProvider = NotifierProvider<AuthController, AuthControllerState>(AuthController.new);
