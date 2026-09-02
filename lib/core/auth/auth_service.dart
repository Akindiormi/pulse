enum AuthStatus { unauthenticated, authenticating, authenticated, authenticatedUnverified, error }

class AuthState {
  const AuthState({required this.status, this.uid, this.message});
  final AuthStatus status;
  final String? uid;
  final String? message;
}

abstract interface class AuthService {
  Stream<AuthState> get authStateChanges;
  Future<AuthState> signInWithGoogle();
  Future<AuthState> signInWithApple();
  Future<AuthState> signInWithEmail({required String email, required String password});
  Future<AuthState> registerWithEmail({required String email, required String password});
  Future<void> sendEmailVerification();
  Future<void> signOut();
  Future<void> deleteAccount();
}
