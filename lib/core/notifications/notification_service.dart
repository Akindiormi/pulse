abstract interface class NotificationService {
  Future<void> initialize();
  Future<void> requestPermission();
  Future<String?> getToken();
  Future<void> scheduleDailyChallengeReminder({required int hour, required int minute});
}

class NoopNotificationService implements NotificationService {
  const NoopNotificationService();
  @override Future<void> initialize() async {}
  @override Future<void> requestPermission() async {}
  @override Future<String?> getToken() async => null;
  @override Future<void> scheduleDailyChallengeReminder({required int hour, required int minute}) async {}
}
