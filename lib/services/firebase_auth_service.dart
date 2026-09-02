import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import '../backend/trusted_account_backend.dart';
import '../core/errors/app_error.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth, this._accountBackend);
  final FirebaseAuth _auth;
  final TrustedAccountBackend _accountBackend;

  @override
  Stream<AuthState> get authStateChanges => _auth.userChanges().map(_mapUser);

  AuthState _mapUser(User? user) => user == null
      ? const AuthState(status: AuthStatus.unauthenticated)
      : AuthState(status: user.emailVerified ? AuthStatus.authenticated : AuthStatus.authenticatedUnverified, uid: user.uid);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(e.code);
    }
  }

  @override
  Future<AuthState> signInWithGoogle() async => throw const AuthFailure('provider-not-supported');

  @override
  Future<AuthState> signInWithApple() async => throw const AuthFailure('provider-not-supported');

  @override
  Future<AuthState> signInWithEmail({required String email, required String password}) async => _guard(() async {
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return _mapUser(result.user);
  });

  @override
  Future<AuthState> registerWithEmail({required String email, required String password}) async => _guard(() async {
    final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return _mapUser(result.user);
  });

  @override
  Future<void> sendEmailVerification() async => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('session-expired');
    await user.sendEmailVerification();
  });

  @override
  Future<bool> reloadVerificationState() async => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  });

  @override
  Future<void> sendPasswordResetEmail({required String email}) => _guard(() => _auth.sendPasswordResetEmail(email: email));

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Firestore cleanup runs first so the authenticated callable can verify the
    // current UID. It is retryable if Auth deletion later fails.
    await _accountBackend.deleteAccountData();
    await _guard(() => user.delete());
  }
}
