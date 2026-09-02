import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

class FirebaseNotificationService implements NotificationService {
  FirebaseNotificationService(this.messaging);
  final FirebaseMessaging messaging;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async {
    final settings = await messaging.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => NotificationPermissionStatus.authorized,
      AuthorizationStatus.provisional => NotificationPermissionStatus.provisional,
      AuthorizationStatus.denied => NotificationPermissionStatus.denied,
      AuthorizationStatus.notDetermined => NotificationPermissionStatus.notDetermined,
    };
  }

  @override
  Future<void> requestPermission() async {
    await messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  @override
  Future<String?> getToken() => messaging.getToken();

  @override
  Future<void> scheduleDailyChallengeReminder({required int hour, required int minute}) async {
    throw UnsupportedError('FCM does not schedule local delivery times; configure the daily reminder in the trusted backend/Cloud Scheduler.');
  }

  @override
  Future<void> cancelDailyChallengeReminder() async {}
}
