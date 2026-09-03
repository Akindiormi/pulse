enum AppErrorKind { validation, network, auth, provider, verification, profile, timeout, offline, unknown }
class AppError { const AppError({required this.kind, required this.message, this.retryable = false, this.cancelled = false}); final AppErrorKind kind; final String message; final bool retryable; final bool cancelled; }
class ErrorMessageMapper {
  const ErrorMessageMapper._();
  static AppError from(Object error, {AppErrorKind kind = AppErrorKind.unknown}) {
    final code = error is AuthFailure ? error.code : '';
    if (code == 'network-request-failed') return const AppError(kind: AppErrorKind.network, message: 'couldn’t establish a connection right now. check your internet and try again.', retryable: true);
    if (code == 'too-many-requests') return const AppError(kind: AppErrorKind.auth, message: 'too many attempts. wait a little and try again.', retryable: true);
    if (code == 'invalid-credential' || code == 'wrong-password' || code == 'user-not-found') return const AppError(kind: AppErrorKind.auth, message: 'those details don’t look right. check your email and password and try again.');
    if (code == 'email-already-in-use') return const AppError(kind: AppErrorKind.auth, message: 'those details can’t be used to create this account. try signing in instead.');
    if (code == 'weak-password') return const AppError(kind: AppErrorKind.validation, message: 'that password is too weak. try using a stronger password.');
    if (code == 'invalid-email') return const AppError(kind: AppErrorKind.validation, message: 'enter a valid email address.');
    if (code == 'user-disabled') return const AppError(kind: AppErrorKind.auth, message: 'this account is currently unavailable.');
    if (code == 'session-expired') return const AppError(kind: AppErrorKind.auth, message: 'your session has expired. sign in again.');
    if (code == 'provider-not-supported') return const AppError(kind: AppErrorKind.provider, message: 'that sign-in option isn’t available yet. use email for now.');
    if (error is TimeoutExceptionMarker) return const AppError(kind: AppErrorKind.timeout, message: 'that took too long. check your connection and try again.', retryable: true);
    if (error is AuthCancelled) return const AppError(kind: AppErrorKind.provider, message: '', cancelled: true);
    return AppError(kind: kind, message: 'something went wrong. try again.', retryable: true);
  }
}
class AuthFailure implements Exception { const AuthFailure(this.code); final String code; }
class AuthCancelled implements Exception { const AuthCancelled(); }
class TimeoutExceptionMarker implements Exception { const TimeoutExceptionMarker(); }
