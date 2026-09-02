import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/errors/app_error.dart';

void main() {
  test('maps invalid credentials to a safe message', () {
    final error = ErrorMessageMapper.from(const AuthFailure('invalid-credential'), kind: AppErrorKind.auth);
    expect(error.message, contains('details don’t look right'));
    expect(error.message, isNot(contains('Firebase')));
  });

  test('maps provider cancellation without alarming the user', () {
    final error = ErrorMessageMapper.from(const AuthCancelled(), kind: AppErrorKind.provider);
    expect(error.cancelled, isTrue);
    expect(error.message, isEmpty);
  });

  test('maps network failure to a retryable message', () {
    final error = ErrorMessageMapper.from(const AuthFailure('network-request-failed'));
    expect(error.retryable, isTrue);
    expect(error.message, contains('connection'));
  });
}
