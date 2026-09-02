import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding persistence key is local UX state', () {
    const key = 'pulse.onboarding_completed';
    expect(key, startsWith('pulse.'));
    expect(key, isNot(contains('password')));
    expect(key, isNot(contains('token')));
  });
}
