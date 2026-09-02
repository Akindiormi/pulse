import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/database/repositories.dart';

void main() {
  test('display-name-only update preserves existing photoUrl and unrelated fields', () {
    final existing = <String, dynamic>{
      'displayName': 'old name',
      'photoUrl': 'https://example.com/avatar.jpg',
      'timezone': 'Africa/Lagos',
      'notificationPreferences': <String, dynamic>{'dailyReminder': true},
    };
    final patch = const UserProfileUpdate({'displayName': 'new name'}).toFirestore();
    final updated = <String, dynamic>{...existing, ...patch};

    expect(updated['displayName'], 'new name');
    expect(updated['photoUrl'], existing['photoUrl']);
    expect(updated['timezone'], existing['timezone']);
    expect(updated['notificationPreferences'], existing['notificationPreferences']);
  });

  test('explicit profile fields can be changed without adding unrelated fields', () {
    final patch = const UserProfileUpdate({
      'displayName': 'new name',
      'timezone': 'Africa/Lagos',
      'notificationPreferences': <String, dynamic>{'dailyReminder': false},
    }).toFirestore();

    expect(patch.keys, containsAll(<String>['displayName', 'timezone', 'notificationPreferences']));
    expect(patch.containsKey('photoUrl'), isFalse);
  });

  test('unsupported profile fields are rejected', () {
    expect(
      () => const UserProfileUpdate({'xp': 999}).toFirestore(),
      throwsArgumentError,
    );
  });
}
