import 'package:firebase_core/firebase_core.dart';

abstract interface class FirebaseBootstrap {
  Future<FirebaseApp> initialize();
}

class DefaultFirebaseBootstrap implements FirebaseBootstrap {
  const DefaultFirebaseBootstrap();

  @override
  Future<FirebaseApp> initialize() => Firebase.initializeApp();
}

class FirebaseServiceBoundaries {
  const FirebaseServiceBoundaries();
}

/// This boundary intentionally does not contain generated firebase_options.dart.
/// Configure the real Firebase project locally with FlutterFire and the native
/// platform files before running a connected build. Do not commit credentials.
