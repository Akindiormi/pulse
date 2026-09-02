import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

class FirebaseNotificationService implements NotificationService {
  FirebaseNotificationService(this.messaging);
  final FirebaseMessaging messaging;

  @override
  Future<void> initialize() async {
    await messaging.subscribeToTopic('daily_challenge_reminders');
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
}
