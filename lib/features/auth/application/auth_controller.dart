import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_error.dart';

class AuthController extends Notifier<AuthControllerState> {
  @override AuthControllerState build() => const AuthControllerState();

  Future<AuthState?> signIn(String email, String password) async {
    if (state.loading) return null;
    state = state.copyWith(loading: true, error: null);
    try { final result = await ref.read(authServiceProvider).signInWithEmail(email: email.trim(), password: password); state = state.copyWith(loading: false); return result; }
    catch (e) { state = state.copyWith(loading: false, error: ErrorMessageMapper.from(e, kind: AppErrorKind.auth)); return null; }
  }

  Future<AuthState?> signUp(String email, String password) async {
    if (state.loading) return null;
    state = state.copyWith(loading: true, error: null);
    try { final result = await ref.read(authServiceProvider).registerWithEmail(email: email.trim(), password: password); state = state.copyWith(loading: false); return result; }
    catch (e) { state = state.copyWith(loading: false, error: ErrorMessageMapper.from(e, kind: AppErrorKind.auth)); return null; }
  }

  Future<AppError?> resetPassword(String email) async {
    if (state.loading) return null;
    state = state.copyWith(loading: true, error: null);
    try { await ref.read(authServiceProvider).sendPasswordResetEmail(email: email.trim()); state = state.copyWith(loading: false); return null; }
    catch (e) { final error = ErrorMessageMapper.from(e, kind: AppErrorKind.auth); state = state.copyWith(loading: false, error: error); return error; }
  }

  void clearError() => state = state.copyWith(error: null);
}

class AuthControllerState {
  const AuthControllerState({this.loading = false, this.error});
  final bool loading;
  final AppError? error;
  AuthControllerState copyWith({bool? loading, AppError? error, bool clearError = false}) => AuthControllerState(loading: loading ?? this.loading, error: clearError ? null : (error ?? this.error));
}

final authControllerProvider = NotifierProvider<AuthController, AuthControllerState>(AuthController.new);
