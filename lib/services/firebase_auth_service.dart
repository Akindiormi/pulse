import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);
  final FirebaseAuth _auth;
  @override
  Stream<AuthState> get authStateChanges => _auth.userChanges().map(_mapUser);
  AuthState _mapUser(User? user) => user == null ? const AuthState(status: AuthStatus.unauthenticated) : AuthState(status: user.emailVerified ? AuthStatus.authenticated : AuthStatus.authenticatedUnverified, uid: user.uid);
  @override Future<AuthState> signInWithGoogle() async => throw UnimplementedError('Google provider wiring requires Firebase project configuration.');
  @override Future<AuthState> signInWithApple() async => throw UnimplementedError('Apple provider wiring requires Firebase project configuration.');
  @override Future<AuthState> signInWithEmail({required String email, required String password}) async { final result = await _auth.signInWithEmailAndPassword(email: email, password: password); return _mapUser(result.user); }
  @override Future<AuthState> registerWithEmail({required String email, required String password}) async { final result = await _auth.createUserWithEmailAndPassword(email: email, password: password); return _mapUser(result.user); }
  @override Future<void> sendEmailVerification() async => _auth.currentUser?.sendEmailVerification();
  @override Future<void> signOut() => _auth.signOut();
  @override Future<void> deleteAccount() => _auth.currentUser?.delete() ?? Future.value();
}
