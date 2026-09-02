import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'crash_reporter.dart';

class FirebaseCrashReporter implements CrashReporter {
  FirebaseCrashReporter(this.crashlytics);
  final FirebaseCrashlytics crashlytics;

  @override
  Future<void> recordError(Object error, StackTrace stack, {String? reason}) => crashlytics.recordError(error, stack, reason: reason);
}
