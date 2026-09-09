import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../auth/auth_service.dart';
import '../backend/trusted_account_backend.dart';
import '../backend/trusted_challenge_backend.dart';
import '../database/repositories.dart';
import '../database/supabase_repositories.dart';
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
import '../../services/supabase_auth_service.dart';

final supabaseProvider = Provider<supabase.SupabaseClient>((ref) => supabase.Supabase.instance.client);
final analyticsProvider = Provider<FirebaseAnalytics>((ref) => FirebaseAnalytics.instance);
final messagingProvider = Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);
final crashlyticsProvider = Provider<FirebaseCrashlytics>((ref) => FirebaseCrashlytics.instance);

final trustedCallableClientProvider = Provider<TrustedCallableClient>((ref) => SupabaseTrustedCallableClient(ref.watch(supabaseProvider)));
final trustedAccountBackendProvider = Provider<TrustedAccountBackend>((ref) => SupabaseCallableAccountBackend(ref.watch(trustedCallableClientProvider)));
final authServiceProvider = Provider<AuthService>((ref) => SupabaseAuthService(ref.watch(supabaseProvider), ref.watch(trustedAccountBackendProvider)));
final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(authServiceProvider).authStateChanges);
final userRepositoryProvider = Provider<UserRepository>((ref) => SupabaseUserRepository(ref.watch(supabaseProvider)));
final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) => SupabaseChallengeRepository(ref.watch(supabaseProvider)));
final activityRepositoryProvider = Provider<ActivityRepository>((ref) => SupabaseActivityRepository(ref.watch(supabaseProvider)));
final achievementRepositoryProvider = Provider<AchievementRepository>((ref) => SupabaseAchievementRepository(ref.watch(supabaseProvider)));

final trustedChallengeBackendProvider = Provider<TrustedChallengeBackend>((ref) => SupabaseTrustedChallengeBackend(ref.watch(trustedCallableClientProvider), ref.watch(authServiceProvider)));
final achievementServiceProvider = Provider<AchievementService>((ref) => const AchievementService());
final challengeServiceProvider = Provider<ChallengeService>((ref) => ChallengeService(repository: ref.watch(challengeRepositoryProvider), backend: ref.watch(trustedChallengeBackendProvider)));
final completeChallengeProvider = Provider<CompleteChallenge>((ref) => CompleteChallenge(backend: ref.watch(trustedChallengeBackendProvider));

final analyticsServiceProvider = Provider<AnalyticsService>((ref) => FirebaseAnalyticsService(ref.watch(analyticsProvider)));
final pulseEventDispatcherProvider = Provider<PulseEventDispatcher>((ref) => PulseEventDispatcher(ref.watch(analyticsServiceProvider)));
final crashReporterProvider = Provider<CrashReporter>((ref) => FirebaseCrashReporter(ref.watch(crashlyticsProvider)));
final notificationServiceProvider = Provider<NotificationService>((ref) => FirebaseNotificationService(ref.watch(messagingProvider)));
