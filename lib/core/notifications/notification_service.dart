enum NotificationPermissionStatus { authorized, provisional, denied, notDetermined, unavailable }

abstract interface class NotificationService {
  Future<void> initialize();
  Future<NotificationPermissionStatus> getPermissionStatus() async => NotificationPermissionStatus.unavailable;
  Future<void> requestPermission();
  Future<String?> getToken();
  Future<void> scheduleDailyChallengeReminder({required int hour, required int minute});
  Future<void> cancelDailyChallengeReminder() async {}
}

class NoopNotificationService implements NotificationService {
  const NoopNotificationService();
  @override Future<void> initialize() async {}
  @override Future<NotificationPermissionStatus> getPermissionStatus() async => NotificationPermissionStatus.unavailable;
  @override Future<void> requestPermission() async {}
  @override Future<String?> getToken() async => null;
  @override Future<void> scheduleDailyChallengeReminder({required int hour, required int minute}) async {}
  @override Future<void> cancelDailyChallengeReminder() async {}
}
