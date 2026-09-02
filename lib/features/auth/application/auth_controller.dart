import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_error.dart';

enum AuthFlowStatus { idle, loading, success, error, cancelled, verificationRequired }

class AuthController extends Notifier<AuthControllerState> {
  @override AuthControllerState build() => const AuthControllerState();
  Future<AuthState?> signIn(String email, String password) async {
    if (state.loading) return null; state = state.copyWith(status: AuthFlowStatus.loading, error: null);
    try { final result = await ref.read(authServiceProvider).signInWithEmail(email: email.trim(), password: password); state = state.copyWith(status: result.status == AuthStatus.authenticatedUnverified ? AuthFlowStatus.verificationRequired : AuthFlowStatus.success); return result; }
    catch (e) { final error = ErrorMessageMapper.from(e, kind: AppErrorKind.auth); state = state.copyWith(status: error.cancelled ? AuthFlowStatus.cancelled : AuthFlowStatus.error, error: error); await ref.read(analyticsServiceProvider).logAuthFailed('email_sign_in'); return null; }
  }
  Future<AuthState?> signUp(String email, String password) async {
    if (state.loading) return null; state = state.copyWith(status: AuthFlowStatus.loading, error: null);
    try { final result = await ref.read(authServiceProvider).registerWithEmail(email: email.trim(), password: password); state = state.copyWith(status: result.status == AuthStatus.authenticatedUnverified ? AuthFlowStatus.verificationRequired : AuthFlowStatus.success); return result; }
    catch (e) { final error = ErrorMessageMapper.from(e, kind: AppErrorKind.auth); state = state.copyWith(status: error.cancelled ? AuthFlowStatus.cancelled : AuthFlowStatus.error, error: error); await ref.read(analyticsServiceProvider).logAuthFailed('email_sign_up'); return null; }
  }
  Future<AppError?> resetPassword(String email) async {
    if (state.loading) return null; state = state.copyWith(status: AuthFlowStatus.loading, error: null);
    try { await ref.read(authServiceProvider).sendPasswordResetEmail(email: email.trim()); state = state.copyWith(status: AuthFlowStatus.success); return null; }
    catch (e) { final error = ErrorMessageMapper.from(e, kind: AppErrorKind.auth); state = state.copyWith(status: error.cancelled ? AuthFlowStatus.cancelled : AuthFlowStatus.error, error: error); await ref.read(analyticsServiceProvider).logAuthFailed('password_reset'); return error; }
  }
  void clearError() => state = state.copyWith(error: null, status: AuthFlowStatus.idle);
}
class AuthControllerState {
  const AuthControllerState({this.status = AuthFlowStatus.idle, this.error}); final AuthFlowStatus status; final AppError? error; bool get loading => status == AuthFlowStatus.loading;
  AuthControllerState copyWith({AuthFlowStatus? status, AppError? error, bool clearError = false}) => AuthControllerState(status: status ?? this.status, error: clearError ? null : (error ?? this.error));
}
final authControllerProvider = NotifierProvider<AuthController, AuthControllerState>(AuthController.new);
