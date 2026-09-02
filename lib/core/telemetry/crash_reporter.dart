abstract interface class CrashReporter {
  Future<void> recordError(Object error, StackTrace stack, {String? reason});
}
