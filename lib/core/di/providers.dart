import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';
import '../backend/trusted_account_backend.dart';
import '../backend/trusted_challenge_backend.dart';
import '../database/firestore_repositories.dart';
import '../database/repositories.dart';
import '../motion/pulse_event_dispatcher.dart';
import '../notifications/firebase_notification_service.dart';
import '../notifications/notification_service.dart';
import '../telemetry/analytics_service.dart';
import '../telemetry/crash_reporter.dart';
import '../telemetry/firebase_analytics_service.dart';
import '../telemetry/firebase_crash_reporter.dart';
import '../../features/achievements/application/achievement_service.dart';
import '../../features/challenges/application/challenge_service.dart';
import '../../features/challenges/application/complete_challenge.dart';
import '../../services/firebase_auth_service.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final functionsProvider = Provider<FirebaseFunctions>((ref) => FirebaseFunctions.instanceFor(region: 'us-central1'));
final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final analyticsProvider = Provider<FirebaseAnalytics>((ref) => FirebaseAnalytics.instance);
final messagingProvider = Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);
final crashlyticsProvider = Provider<FirebaseCrashlytics>((ref) => FirebaseCrashlytics.instance);

final trustedCallableClientProvider = Provider<TrustedCallableClient>((ref) => FirebaseTrustedCallableClient(ref.watch(functionsProvider)));
final trustedAccountBackendProvider = Provider<TrustedAccountBackend>((ref) => FirebaseCallableAccountBackend(ref.watch(trustedCallableClientProvider)));
final authServiceProvider = Provider<AuthService>((ref) => FirebaseAuthService(ref.watch(authProvider), ref.watch(trustedAccountBackendProvider)));
final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(authServiceProvider).authStateChanges);
final userRepositoryProvider = Provider<UserRepository>((ref) => FirestoreUserRepository(ref.watch(firestoreProvider)));
final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) => FirestoreChallengeRepository(ref.watch(firestoreProvider)));
final activityRepositoryProvider = Provider<ActivityRepository>((ref) => FirestoreActivityRepository(ref.watch(firestoreProvider)));
final achievementRepositoryProvider = Provider<AchievementRepository>((ref) => FirestoreAchievementRepository(ref.watch(firestoreProvider)));

final trustedChallengeBackendProvider = Provider<TrustedChallengeBackend>((ref) => FirebaseCallableChallengeBackend(ref.watch(trustedCallableClientProvider), ref.watch(authServiceProvider)));
final achievementServiceProvider = Provider<AchievementService>((ref) => const AchievementService());
final challengeServiceProvider = Provider<ChallengeService>((ref) => ChallengeService(repository: ref.watch(challengeRepositoryProvider), backend: ref.watch(trustedChallengeBackendProvider)));
final completeChallengeProvider = Provider<CompleteChallenge>((ref) => CompleteChallenge(backend: ref.watch(trustedChallengeBackendProvider)));

final analyticsServiceProvider = Provider<AnalyticsService>((ref) => FirebaseAnalyticsService(ref.watch(analyticsProvider)));
final pulseEventDispatcherProvider = Provider<PulseEventDispatcher>((ref) => PulseEventDispatcher(ref.watch(analyticsServiceProvider)));
final crashReporterProvider = Provider<CrashReporter>((ref) => FirebaseCrashReporter(ref.watch(crashlyticsProvider)));
final notificationServiceProvider = Provider<NotificationService>((ref) => FirebaseNotificationService(ref.watch(messagingProvider)));
