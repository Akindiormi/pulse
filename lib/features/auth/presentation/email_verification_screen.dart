import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/pulse_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/motion/pulse_motion_attachment.dart';
import '../../../core/motion/pulse_motion_state.dart';
import '../../../core/widgets/pulse_button.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget { const EmailVerificationScreen({super.key}); @override ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState(); }
class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool loading = false; String? error; DateTime? nextResend; Timer? timer; int seconds = 0;
  @override void dispose() { timer?.cancel(); super.dispose(); }
  void _startCooldown() { timer?.cancel(); setState(() { nextResend = DateTime.now().add(const Duration(seconds: 30)); seconds = 30; }); timer = Timer.periodic(const Duration(seconds: 1), (_) { if (!mounted) return; final left = nextResend!.difference(DateTime.now()).inSeconds; if (left <= 0) { timer?.cancel(); setState(() => seconds = 0); } else setState(() => seconds = left); }); }
  Future<void> resend() async { if (loading || seconds > 0) return; setState(() { loading = true; error = null; }); try { await ref.read(authServiceProvider).sendEmailVerification(); await ref.read(analyticsServiceProvider).logEmailVerificationSent(); if (mounted) { setState(() => loading = false); _startCooldown(); } } catch (e) { if (mounted) setState(() { loading = false; error = ErrorMessageMapper.from(e, kind: AppErrorKind.verification).message; }); } }
  Future<void> check() async { if (loading) return; setState(() { loading = true; error = null; }); try { final verified = await ref.read(authServiceProvider).reloadVerificationState(); if (!mounted) return; if (verified) { await ref.read(analyticsServiceProvider).logEmailVerificationCompleted(); if (mounted) context.go('/splash'); } else setState(() { loading = false; error = 'your email hasn’t been verified yet. check your inbox and try again.'; }); } catch (e) { if (mounted) setState(() { loading = false; error = ErrorMessageMapper.from(e, kind: AppErrorKind.verification).message; }); } }
  Future<void> useDifferentAccount() async { if (loading) return; setState(() => loading = true); try { await ref.read(authServiceProvider).signOut(); } finally { if (mounted) { setState(() => loading = false); context.go('/auth'); } } }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, padding: const EdgeInsets.all(PulseSpace.xl), children: [const SizedBox(height: PulseSpace.giant), PulseMotionAttachment(intent: PulseMotionIntent.onboardingTransition, state: PulseMotionState.entering, child: Text('check your inbox.', style: Theme.of(context).textTheme.displayLarge), excludeFromSemantics: false), const SizedBox(height: PulseSpace.md), Text('we sent a verification link to your email. verify it, then come back here.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: PulseSpace.xl), if (error != null) Semantics(liveRegion: true, child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))), const SizedBox(height: PulseSpace.lg), PulseMotionBoundaryV2(intent: PulseMotionIntent.onboardingCta, state: loading ? PulseMotionState.loading : PulseMotionState.idle, child: PulseButton(expand: true, onPressed: loading ? null : check, loading: loading, label: 'i’ve verified')), const SizedBox(height: PulseSpace.sm), PulseButton(expand: true, variant: PulseButtonVariant.secondary, onPressed: loading || seconds > 0 ? null : resend, label: seconds > 0 ? 'resend available in ${seconds}s' : 'resend email'), const SizedBox(height: PulseSpace.giant), PulseButton(variant: PulseButtonVariant.tertiary, onPressed: loading ? null : useDifferentAccount, label: 'use a different account')])));
}
