enum AuthStatus { unauthenticated, authenticating, authenticated, authenticatedUnverified, error }

class AuthState {
  const AuthState({required this.status, this.uid, this.message});
  final AuthStatus status;
  final String? uid;
  final String? message;
}

abstract interface class AuthService {
  Stream<AuthState> get authStateChanges;
  /// Email of the currently signed-in-but-unverified user, if any. Used to
  /// verify a signup code without re-threading the email through navigation.
  String? get pendingEmail;
  Future<AuthState> signInWithGoogle();
  Future<AuthState> signInWithApple();
  Future<AuthState> signInWithEmail({required String email, required String password});
  Future<AuthState> registerWithEmail({required String email, required String password});
  Future<void> sendEmailVerification();
  /// Verifies signup via a one-time code (sent by email) instead of a
  /// clickable link, so there is no browser redirect involved at all.
  Future<AuthState> verifySignUpCode({required String email, required String code});
  Future<bool> reloadVerificationState();
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> signOut();
  Future<void> deleteAccount();
}
